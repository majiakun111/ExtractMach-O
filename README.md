# ExtractMach-O 
1. 在终端执行 otool -oV mach-o的path > dataSegment.txt //生成所有data segment的信息
2. 在终端执行 otool -v -s __DATA __objc_selrefs mach-o的path > methodRefs.txt  ///生成被调用的Method
3. 把第一步 第二部生成的 dataSegment.txt和methodRefs.txt 替换工程中的
4. 执行工程
