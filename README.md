# 一键DD脚本

## 注意

全自动安装默认ROOT密码:```haoduck.com```  

支持自定义ROOT密码、SSH端口(Linux)  

特别注意:OpenVZ构架不适用.

## 傻瓜式一键脚本
```
curl -sSL -k -o dd.sh https://raw.githubusercontent.com/haoduck/dd/master/dd.sh && chmod +x dd.sh && bash dd.sh
```

```
curl -sSL -k -o dd.sh https://fastly.jsdelivr.net/gh/haoduck/dd@latest/dd.sh && chmod +x dd.sh && bash dd.sh
```

## Tip

谷歌云GCP使用时需要把掩码手动改为255.255.255.0


部分代码copy自 https://github.com/veip007/dd 以及 https://github.com/hiCasper/Shell 。主要是添加了自定义ROOT密码和SSH端口，有现成的代码就偷懒了。