USE master
IF EXISTS(select * from sys.databases where name='SqlUtils')
DROP DATABASE SqlUtils

CREATE DATABASE SqlUtils;

USE SqlUtils
