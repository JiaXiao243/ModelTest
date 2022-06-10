chcp 65001

set PATH=C:\Windows\System32; %PATH%

rem paddlespeech
python -m pip uninstall -y paddlespeech
python -m pip install .

export http_proxy=
export https_proxy=

python 
rem offline
cd demos/speech_server
wget -c https://paddlespeech.bj.bcebos.com/PaddleAudio/zh.wav https://paddlespeech.bj.bcebos.com/PaddleAudio/en.wav
rem sed -i "s/device: /device: 'cpu'/g"  ./conf/application.yaml
start paddlespeech_server start --config_file ./conf/application.yaml
timeout /nobreak /t 60

rem asr
paddlespeech_client asr --server_ip 127.0.0.1 --port 8090 --input ./zh.wav
call :printFun asr_offline
paddlespeech_client tts --server_ip 127.0.0.1 --port 8090 --input "您好，欢迎使用百度飞桨语音合成服务。" --output output.wav
call :printFun tts_offline
paddlespeech_client cls --server_ip 127.0.0.1 --port 8090 --input ./zh.wav
call :printFun cls_offline
rem speaker vertification

wget -c https://paddlespeech.bj.bcebos.com/vector/audio/85236145389.wav
rem cp 85236145389.wav 123456789.wav
paddlespeech_client vector --task spk  --server_ip 127.0.0.1 --port 8090 --input 85236145389.wav
call :printFun vector_spk_offline
paddlespeech_client vector --task score  --server_ip 127.0.0.1 --port 8090 --enroll 85236145389.wav --test 85236145389.wav
call :printFun vector_score_offline
rem text
paddlespeech_client text --server_ip 127.0.0.1 --port 8090 --input "我认为跑步最重要的就是给我带来了身体健康"
call :printFun text_offline

taskkill /f /im paddlespeech_server*

:printFun
if not %errorlevel% == 0 (
        echo  %~1 predict failed!
) else (
        echo  %~1 predict successfully!
)
EXIT /B 0

