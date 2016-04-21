@ECHO OFF
SET NGFOLDER=D:\PROGRAM_FILES\nginx-1.8.0\
CD %NGFOLDER%

SET root=%~dp0
SET root=%root:\=/%
ECHO New root: %root%
ECHO root %root%/; > %NGFOLDER%conf\custom.conf
ECHO autoindex on; >> %NGFOLDER%conf\custom.conf
tasklist /fi "imagename eq nginx.exe" | find /C "nginx.exe" > nul
REM EXIST logs/nginx.pid
IF %errorlevel% EQU 0 (
	ECHO Reloading config.
	start %NGFOLDER%nginx.exe -s reload
) else (
	ECHO Starting!
	start %NGFOLDER%nginx.exe
)
CD %~dp0
ping -n 2 localhost > nul
tasklist /fi "imagename eq nginx.exe"
pause