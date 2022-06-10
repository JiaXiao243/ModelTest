chcp 65001

set PATH=C:\Program Files (x86)\GnuWin32; %PATH%
md log

set log_path=%~dp0\log
rem paddlespeech
python -m pip uninstall -y paddlespeech
python -m pip install .

set http_proxy=
set https_proxy=

python 
rem offline
cd demos/speech_server
wget -c https://paddlespeech.bj.bcebos.com/PaddleAudio/zh.wav https://paddlespeech.bj.bcebos.com/PaddleAudio/en.wav
rem sed -i "s/device: /device: 'cpu'/g"  ./conf/application.yaml
start paddlespeech_server start --config_file ./conf/application.yaml
call :timeoutFun 60

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
call :killFun

rem  online_tts
cd ../streaming_tts_server
rem  http
start paddlespeech_server start --config_file ./conf/tts_online_application.yaml 2>&1 &
call :timeoutFun 30

paddlespeech_client tts_online --server_ip 127.0.0.1 --port 8092 --protocol http --input "�~B�好�~L欢�~N使�~T��~Y�度�~^桨语�~_��~P~H�~H~P�~\~M�~J��~@~B" --output output.wav
call :printFun tts_online_http
call :killFun

rem websocket
set sed="C:\Program Files\Git\usr\bin\sed.exe"
%sed% -i s/"http"/"websocket"/g ./conf/tts_online_application.yaml
rem sed -i "s/device: 'cpu'/device: 'gpu:5'/g" ./conf/tts_online_application.yaml
start paddlespeech_server start --config_file ./conf/tts_online_application.yaml 2>&1 &
call :timeoutFun 30

paddlespeech_client tts_online --server_ip 127.0.0.1 --port 8092 --protocol websocket --input "�~B�好�~L欢�~N使�~T��~Y�度�~^桨语�~_��~P~H�~H~P�~\~M�~J��~@~B" --output output.wav
call :printFun tts_online_websockert
call :killFun

rem online_asr
cd ../streaming_asr_server
wget -c https://paddlespeech.bj.bcebos.com/PaddleAudio/zh.wav https://paddlespeech.bj.bcebos.com/PaddleAudio/en.wav

rem sed -i "s/device: 'cpu' /device: 'gpu:5'/g"  ./conf/ws_conformer_wenetspeech_application.yaml
start paddlespeech_server start --config_file ./conf/ws_conformer_wenetspeech_application.yaml 2>&1 &
call :timeoutFun 30

paddlespeech_client asr_online --server_ip 127.0.0.1 --port 8090 --input ./zh.wav
call :printFun asr_online_websockert
call :killFun

rem function
:printFun
if not %errorlevel% == 0 (
        echo  %~1 predict failed!
) else (
        echo  %~1 predict successfully!
)
EXIT /B 0

:timeoutFun
ping -n %~1 127.0.0.1 >NUL
rem timeout /nobreak /t 30
EXIT /B 0

:killFun
taskkill /f /im paddlespeech_server*
rem taskkill /f /im python.exe
EXIT /B 0

:printFun
if not %errorlevel% == 0 (
        echo  %~1 predict failed!
        echo  %~1 predict failed! >> %log_path%/result.log
) else (
        echo  %~1 predict successfully!
        echo  %~1 predict successfully! >> %log_path%/result.log
)
EXIT /B 0

findstr "failed" >> %log_path%/result.log >nul
if errorlevel 0 (
echo �fialed!!
) else (
echo success!!!
)
