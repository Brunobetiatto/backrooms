@echo off
rem Gera o NerdolasBackrooms.exe na pasta do jogo usando o compilador C# que vem com o Windows.
cd /d "%~dp0"
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe /out:..\NerdolasBackrooms.exe /resource:atualizar.ps1,atualizar.ps1 NerdolasBackrooms.cs
