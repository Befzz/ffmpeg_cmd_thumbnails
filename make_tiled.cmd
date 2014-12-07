@ECHO OFF
cd "%~dp0" 
chcp 65001 > nul
SETLOCAL EnableDelayedExpansion

SET FFFOLDER=D:\Down_Chrome\_part2\ffmpeg-20141009-git-f6777ce-win32-static\ffmpeg-20141009-git-f6777ce-win32-static\bin\bin
SET in_path=%1

IF NOT EXIST %1 (
	ECHO [%time%] Error. Not a file: !in_path!
	GOTO exit_label
)
FOR /D %%f IN (!in_path!) DO SET input_file_name=%%~xnf
ECHO [%time%] Working with: !in_path!

SET ev=eval.js
IF EXIST %ev% GOTO script
@echo WScript.echo(eval(WScript.Arguments(0)))>%ev%
:script

GOTO end_of_code
:calc
FOR /f "tokens=1-2 delims=" %%i IN ('cscript %ev% %2 //nologo') DO (
	SET %1=%%i
	echo %1=%%i
)
GOTO :EOF
:end_of_code

SET FILE_STREAMS=streams_info.txt
SET FILE_FORMAT=format_info.txt
IF EXIST %FILE_STREAMS% DEL /Q /F %FILE_STREAMS%
IF EXIST %FILE_FORMAT% DEL /Q /F %FILE_FORMAT%

SET v_stream_found=0
SET stream_type=0
SET last_index=-
SET section_type=0

REM It's may not exists in stream, so predefines as 1:1
SET first_stream_sar=1:1
SET v_codec_name=0
SET last_width=N/A

ECHO [%time%] Gathering info.
FOR /F "usebackq tokens=1-2 delims=^=" %%a in (`%FFFOLDER%\ffprobe.exe -hide_banner -show_streams -show_entries format -loglevel quiet !in_path!`) DO (

	echo %%a = %%b
	echo %%a = %%b >> entries.txt

	IF %%a==duration (
		SET duration=%%b
	)
	IF %%a==codec_type (
		SET stream_type=%%b
		IF %%b==video (
			IF !v_stream_found!==0 (
				SET v_stream_found=1
			)
		)
	)
	IF %%a==index (
		SET last_index=%%b
		SET stream_info=%%b
	)
	IF %%a==[FORMAT] (
		ECHO file name: !input_file_name! >> %FILE_FORMAT%
		SET section_type=FORMAT
	)
	IF %%a==[/FORMAT] SET section_type=0
	IF %%a==[STREAM] SET section_type=STREAM
	IF %%a==[/STREAM] (
		IF !v_stream_found!==1 (
			REM skip future width/height
			SET v_codec_name=!last_codec_name!
			SET v_stream_found=2
		)
		ECHO !stream_info! >> %FILE_STREAMS%
		SET section_type=0
	)
	
	IF %%a==codec_name (
		SET stream_info=!stream_info! %%b
		SET last_codec_name=%%b
	)
	IF %%a==pix_fmt SET stream_info=!stream_info! %%b
	IF %%a==profile (
		IF NOT %%b==unknown SET stream_info=!stream_info! ^(%%b^)
	)
	
	IF %%a==fps SET stream_info=!stream_info! %%b fps
	REM IF %%a==avg_frame_rate (
		REM call :calc fps "%%b"
		REM IF !stream_type!==video SET stream_info=!stream_info! !fps! fps 
	REM )
	IF %%a==width (
		IF NOT %%b==N/A SET last_width=%%b
		IF !v_stream_found!==1 SET v_width=%%b
	)
	IF %%a==height (
		IF NOT %%b==N/A (
			SET stream_info=!stream_info! !last_width!x%%b
		)
		IF !v_stream_found!==1 (
			SET v_height=%%b
		)
	)
	IF %%a==sample_aspect_ratio (
		IF !v_stream_found!==1 (
			SET first_stream_sar=%%b
		)
		SET stream_info=!stream_info!, SAR %%b
	)
	IF %%a==TAG^:language SET stream_info=!stream_info! ^(lang^:%%b^)
	IF %%a==TAG^:title SET stream_info=!stream_info! ^(title:%%b^)
	if %%a==bit_rate (
		IF NOT %%b==N/A (
			SET i_bit_rate=%%b
			SET stream_info=!stream_info!, !i_bit_rate:~0,-3! kbps
		)
	)
	
	IF %%a==channels SET stream_info=!stream_info!, %%bch
	IF %%a==sample_rate SET stream_info=!stream_info!, %%b Hz
	IF %%a==sample_fmt SET stream_info=!stream_info! ^(fmt:%%b^)
	
	IF !section_type!==FORMAT (
		
		setlocal DisableDelayedExpansion
		SET va=%%b
		
		setlocal EnableDelayedExpansion
		rem echo va=!va!
		
		IF %%a==duration           (
			call :calc duration_fmt "function to2(v){v=v.toString();if(v.length==1){return '0'+v}else{return v}};var d=%%b;to2(Math.floor(d/3600))+':'+to2(Math.floor(d/60) %%%% 60)+':'+to2(Math.floor(d) %%%% 60) + ' ('+parseFloat(d)+')'"
			ECHO duration: !duration_fmt! >> %FILE_FORMAT%
		)
		IF %%a==size               (
			call :calc size_fmt "var d=parseInt(%%b),prefix=['','Ki','Mi','Gi','Ti'];var c=Math.floor((d+'').length/3);Math.round(100 * (d/Math.pow(1024,c)))/100 +' '+ prefix[c]"
			ECHO size:      !size_fmt!b  ^(!va! bytes^) >> %FILE_FORMAT%
		)
		IF %%a==bit_rate           (
			call :calc bit_rate_fmt "var d=parseInt(%%b),prefix=['','Ki','Mi','Gi','Ti'];var c=Math.floor((d+'').length/3);Math.round(100 * (d/Math.pow(1024,c)))/100 +' '+ prefix[c]"
			ECHO bit_rate:  !bit_rate_fmt!bps !i_bit_rate! bps >> %FILE_FORMAT%
		)
		IF %%a==TAG^:encoder       ECHO encoder:  !va! >> %FILE_FORMAT%
		IF %%a==TAG^:creation_time ECHO created:  !va! >> %FILE_FORMAT%
		IF %%a==format_name        ECHO format:   !va! >> %FILE_FORMAT%
		endlocal
		endlocal
	)
)
echo W x H = %v_width% x %v_height%

SET FONT_TTF=ARIALUNI.TTF
SET FONT_TTF=unifont-7.0.06.ttf
SET THUMBNAIL_W=240
SET THUMBNAILS_X=8
::for debug - uncomment this:
::SET THUMBNAILS_Y=2

IF %first_stream_sar%==1:1 (
	call :calc THUMBNAIL_H "Math.floor(%v_height% / (%v_width% / %THUMBNAIL_W%))"
) ELSE (
	call :calc THUMBNAIL_H "var s='%first_stream_sar%'.split(':');s0=parseInt(s[0]);s1=parseInt(s[1]);if(s1==0){s1=1};if(s0==0){s0=1};Math.floor(%v_height% / ((%v_width% * s0 / s1) / %THUMBNAIL_W%))"
)
SET DUR_PERCENT=.3
SET LOGO_OFFSET_X=950

call :calc TS "Math.round(100 * %duration% * %DUR_PERCENT%/100)/100"
call :calc total_images "Math.round(10 * %duration% / %TS%)/10"
call :calc tile_rows "Math.ceil(%total_images% / %THUMBNAILS_X%)"
echo tile_rows: %tile_rows%
IF NOT DEFINED THUMBNAILS_Y (
	SET THUMBNAILS_Y=%tile_rows%
)

SET TS=5

SET STREAMS_FONTSIZE=12
IF %last_index% GEQ 5 (
	SET /A last_index=%last_index%+1
) ELSE (
	SET /A last_index=7
)
SET /A pad_height=(STREAMS_FONTSIZE+2)*%last_index%

ECHO Duration: %duration%
ECHO Step: %DUR_PERCENT%%% (min. %TS% seconds)
ECHO Max. images: %total_images%

SET f_select=select=if( not(eq(mod(trunc(prev_pts*TB)\,%TS%)\,0))\,  if(eq(mod(trunc(t)\,%TS%)\,0)\,print(t))\;if( gt((pts - prev_selected_pts) * TB\, %TS%) \,print((pts)*TB)\;1\,eq(mod(trunc(pts*TB)\,%TS%)\, 0))  )
SET f_drawtext=drawtext='fontfile=PTM55FT.ttf:fontsize=8:borderw=1:bordercolor=0x000000@0.5:fontcolor=0xFFFFFF@0.7:text=%%{pts\:hms}:x=5:y=5'
SET f_drawtext_streams=drawtext=fontfile=%FONT_TTF%:fontsize=%STREAMS_FONTSIZE%:textfile=%FILE_STREAMS%:fontcolor=white:x=600:y=5
SET f_drawtext_format=drawtext=fontfile=%FONT_TTF%:fontsize=%STREAMS_FONTSIZE%:textfile=%FILE_FORMAT%:fontcolor=white:x=9:y=5
SET f_drawtext_logo=drawtext=fontfile=PTM55FT.ttf:fontsize=90:text=Powered by FFMPEG:fontcolor=0xFFFFFF:x=%THUMBNAILS_X%*%THUMBNAIL_W%-%LOGO_OFFSET_X%:y=10


::%FFFOLDER%\ffmpeg.exe -skip_frame nokey -y -sn -an -vsync 0 -hide_banner -i %1 -vf "%f_select%,scale=%THUMBNAIL_W%:%THUMBNAIL_H%,%f_drawtext%,tile=%THUMBNAILS_X%x%THUMBNAILS_Y%,pad=%THUMBNAILS_X%*%THUMBNAIL_W%:%THUMBNAILS_Y%*%THUMBNAIL_H%+%pad_height%:0:%pad_height%,%f_drawtext_logo%,%f_drawtext_streams%,%f_drawtext_format%,format=pix_fmts=rgba" -frames 1 -compression_level 9 out%%03d.png

SET /A OV_WIDTH=%THUMBNAILS_X%*%THUMBNAIL_W%
SET /A OV_HEIGHT=%pad_height%
IF EXIST out\*.png (
	DEL /Q out\*.png
	REM echo xx
)
ECHO [%time%] Creating header image.
REM %FFFOLDER%\ffmpeg.exe -y -hide_banner -loglevel error -f lavfi -i color=c=black:s=%OV_WIDTH%x%OV_HEIGHT% -vf "%f_drawtext_logo%,%f_drawtext_streams%,%f_drawtext_format%,format=pix_fmts=rgba" -frames 1 -compression_level 9 out\out_header.png
%FFFOLDER%\ffmpeg.exe -y -hide_banner -f lavfi -i "nullsrc=s=%OV_WIDTH%x%OV_HEIGHT%, format=rgba, geq=r=0:a=255" -f lavfi -i "nullsrc=s=%OV_WIDTH%x%OV_HEIGHT%, geq=lum=255*(X/(W-%LOGO_OFFSET_X% - 30)),format=gray" -f lavfi -i "color=s=%OV_WIDTH%x%OV_HEIGHT%:c=0x000000@1.0,format=rgba" -filter_complex "[0]%f_drawtext_logo%,format=rgba,split[logo1][logo_blur];[logo1]geq=lum=p(X\,Y)*.3,format=gray[alpha1];[logo_blur]geq=lum=p(X\,Y)*.6,format=gray[alpha_blur];[1][alpha_blur] alphamerge [a2];[1][alpha1] alphamerge [a1];[a1] boxblur=3:3[blur];[blur][a2]overlay[logo_out];[2][logo_out]overlay,%f_drawtext_streams%,%f_drawtext_format%" -frames 1  out\out_header.png

IF NOT %errorlevel%==0 GOTO exit_label

ECHO [%time%] Creating rows for tiles. [%v_codec_name%]
REM -skip_frame nokey

IF %v_codec_name%==h264 (
	ECHO Skipping non-key frames for h264 stream.^(much faster and less correct time^)
	SET param_skip= -skip_frame nokey 
) ELSE (
	SET param_skip= 
)
%FFFOLDER%\ffmpeg.exe -y -hide_banner %param_skip% -loglevel info -sn -an -vsync 0 -i !in_path! -vf "%f_select%,scale=%THUMBNAIL_W%:%THUMBNAIL_H%,%f_drawtext%,tile=%THUMBNAILS_X%x1,format=pix_fmts=rgba" -start_number 1 -compression_level 9 out\out_%%05d.png
IF NOT %errorlevel%==0 GOTO exit_label

SET rows_count=-1
FOR /F %%i IN ('DIR /B out') DO (
	SET /A rows_count+=1
)
ECHO Rows count: %rows_count%
CD out

ECHO [%time%] Combining.
%FFFOLDER%\ffmpeg.exe -y -hide_banner -loglevel error -start_number 0 -i out_%%05d.png -i out_header.png -filter_complex "[0:v]tile=1x%rows_count%,pad=w=in_w:h=in_h+%pad_height%:y=%pad_height%[tiles];[tiles][1:v] overlay" ..\out.png
IF NOT %errorlevel%==0 GOTO exit_label
copy ..\out.png !in_path!.png
ECHO [%time%] Done.
:exit_label
pause
::scale='min(280\, iw):-1'
::select=eq(mod(trunc(t)\,100)\,0) * not(eq(mod(trunc(prev_selected_t)\,100)\,0))
::if(isnan(prev_selected_t) + eq(mod(trunc(prev_selected_t)\,100)\,0)\,print(eq(mod(trunc(t)\,100)\,0)) * not(eq(mod(trunc(prev_selected_t)\,100)\,0)))
::if( not(eq(mod(trunc(prev_selected_t)\,100)\,0))\,   print(t)\;eq(mod(trunc(t)\,100)\,0)   \, print(0) )