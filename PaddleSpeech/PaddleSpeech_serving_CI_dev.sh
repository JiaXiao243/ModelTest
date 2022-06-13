unset GREP_OPTIONS
set -x
# echo ${cudaid1}
echo ${cudaid2}
echo ${Data_path}
echo ${paddle_compile}
echo ${model_flag}

mkdir run_env_py37;
ln -s $(which python3.7) run_env_py37/python;
ln -s $(which pip3.7) run_env_py37/pip;
export PATH=$(pwd)/run_env_py37:${PATH};
export http_proxy=${http_proxy}
export https_proxy=${https_proxy}
export no_proxy=bcebos.com;
python -m pip install pip==20.2.4 --ignore-installed;
python -m pip install $4 --no-cache-dir --ignore-installed;
apt-get update
if [[ $5 == 'all' ]];then
   apt-get install -y sox pkg-config libflac-dev libogg-dev libvorbis-dev libboost-dev swig python3-dev
fi
pushd tools; make virtualenv.done; popd
if [ $? -ne 0 ];then
    exit 1
fi
source tools/venv/bin/activate
python -m pip install pip==20.2.4 --ignore-installed;
python -m pip install $4 --no-cache-dir
python -m pip install numpy==1.20.1 --ignore-installed
python -m pip install pyparsing==2.4.7 --ignore-installed
#pip install -e .
pip install .
# fix protobuf upgrade
python -m pip uninstall protobuf -y
python -m pip install protobuf==3.20.1
python -m pip list | grep protobuf
python -c "import sys; print('python version:',sys.version_info[:])";

#system
if [ -d "/etc/redhat-release" ]; then
   echo "######  system centos"
else
   echo "######  system linux"
fi

python -c 'import paddle;print(paddle.version.commit)'


# start
basepath=`pwd`
mkdir log
log_path=${basepath}/log

printFun(){
    if [ $? -eq 0 ];then
    echo -e "\033[33m $1  predict  successfully!\033[0m"|tee -a $log_path/result.log
else
    # cat $log_path/serving.log
    echo -e "\033[31m $1 of predict failed!\033[0m"|tee -a $log_path/result.log
fi
}

killFun(){
ps aux | grep paddlespeech_server | awk '{print $2}' | xargs kill -9
}


# paddlespeech
python -m pip uninstall -y paddlespeech
python -m pip install .

unset http_proxy
unset https_proxy

cd demos/speech_server

if [ ! -f "zh.wav" ]; then
wget -c https://paddlespeech.bj.bcebos.com/PaddleAudio/zh.wav https://paddlespeech.bj.bcebos.com/PaddleAudio/en.wav
fi
# sed -i "s/device: /device: 'cpu'/g"  ./conf/application.yaml
paddlespeech_server start --config_file ./conf/application.yaml 2>&1 &

sleep 480
echo '!!!'
ps aux | grep paddlespeech_server | grep -v grep
ps aux | grep paddlespeech_server | grep -v grep | wc -l
echo '!!!'
# asr
paddlespeech_client asr --server_ip 127.0.0.1 --port 8090 --input ./zh.wav
printFun asr_offline
paddlespeech_client tts --server_ip 127.0.0.1 --port 8090 --input "您好，欢迎使用百度飞桨语音合成服务。" --output output.wav
printFun tts_offline
paddlespeech_client cls --server_ip 127.0.0.1 --port 8090 --input ./zh.wav
printFun cls_offline

# speaker vertification
if [ ! -f "85236145389.wav" ]; then
wget -c https://paddlespeech.bj.bcebos.com/vector/audio/85236145389.wav
cp 85236145389.wav 123456789.wav
fi

paddlespeech_client vector --task spk  --server_ip 127.0.0.1 --port 8090 --input 85236145389.wav
printFun vector_spk_offline
paddlespeech_client vector --task score  --server_ip 127.0.0.1 --port 8090 --enroll 85236145389.wav --test 123456789.wav
printFun vector_score_offline

# text
paddlespeech_client text --server_ip 127.0.0.1 --port 8090 --input "我认为跑步最重要的就是给我带来了身体健康"
printFun text_offline

killFun


## online_tts
cd ../streaming_tts_server
# http
paddlespeech_server start --config_file ./conf/tts_online_application.yaml 2>&1 &
sleep 120

paddlespeech_client tts_online --server_ip 127.0.0.1 --port 8092 --protocol http --input "您好，欢迎使用百度飞桨语音合成服务。" --output output.wav
printFun tts_online_http
killFun

# websocket
sed -i "" 's/http/websocket/g' ./conf/tts_online_application.yaml
# sed -i "s/device: 'cpu'/device: 'gpu:5'/g" ./conf/tts_online_application.yaml

paddlespeech_server start --config_file ./conf/tts_online_application.yaml 2>&1 &
sleep 120
paddlespeech_client tts_online --server_ip 127.0.0.1 --port 8092 --protocol websocket --input "您好，欢迎使用百度飞桨语音合成服务。" --output output.wav
printFun tts_online_websockert
killFun


### online_asr
cd ../streaming_asr_server
if [ ! -f "zh.wav" ]; then
wget -c https://paddlespeech.bj.bcebos.com/PaddleAudio/zh.wav https://paddlespeech.bj.bcebos.com/PaddleAudio/en.wav
fi 

# sed -i "s/device: 'cpu' /device: 'gpu:5'/g"  ./conf/ws_conformer_wenetspeech_application.yaml
paddlespeech_server start --config_file ./conf/ws_conformer_wenetspeech_application.yaml 2>&1 &

sleep 120
# asr
paddlespeech_client asr_online --server_ip 127.0.0.1 --port 8090 --input ./zh.wav
printFun asr_online_websockert 
killFun

# result
num=`cat $log_path/result.log | grep "failed" | wc -l`
if [ "${num}" -gt "0" ];then
echo -e "-----------------------------base cases-----------------------------"
cat $log_path/result.log | grep "failed"
echo -e "--------------------------------------------------------------------"
exit 1
else
exit 0
fi
