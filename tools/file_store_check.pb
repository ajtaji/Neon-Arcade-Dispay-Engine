EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlFile.pbi"
OpenConsole()
Procedure Check(ok.i, message.s)
  If Not ok : PrintN("FAIL " + message) : End 1 : EndIf
EndProcedure
Define path.s = ProgramParameter(0), size.i = 2097189, *bytes, *read, i.i, f.i
*bytes = AllocateMemory(size) : *read = AllocateMemory(size)
Check(Bool(*bytes And *read), "allocation")
For i = 0 To size - 1 : PokeA(*bytes + i, (i * 13 + i / 512 + 17) & 255) : Next
Check(GL_FileStore(path, *bytes, size, #True), "create new including multiple chunks and tail")
Check(Bool(Not GL_FileStore(path, *bytes, 1, #True)), "create new refuses existing")
Check(Bool(Not GL_FileStore(path, *bytes, size - 1)), "existing size mismatch refuses without truncation")
Check(Bool(FileSize(path) = size), "size preserved")
Check(Bool(Not GL_FileStore(path + ".absent", *bytes, size)), "existing-only does not create missing file")
Check(Bool(FileSize(path + ".absent") = -1), "missing stays missing")
f = ReadFile(#PB_Any, path) : Check(Bool(f), "read original")
Check(Bool(ReadData(f, *read, size) = size), "complete original read") : CloseFile(f)
Check(CompareMemory(*read, *bytes, size), "refusals preserve every original byte")
For i = 0 To size - 1 : PokeA(*bytes + i, (i * 7 + 43) & 255) : Next
Check(GL_FileStore(path, *bytes, size), "overwrite existing and sync")
f = ReadFile(#PB_Any, path) : Check(Bool(f), "read committed")
Check(Bool(ReadData(f, *read, size) = size), "complete committed read") : CloseFile(f)
Check(CompareMemory(*read, *bytes, size), "every committed byte")
Check(Bool(Not GL_FileStore(path, 0, 1)), "null payload refused")
Check(Bool(Not GL_FileStore(path, *bytes, -1)), "negative size refused")
PrintN("PASS durable file store: exclusive create, exact-size existing-only update, multiple chunks/tail, complete bytes and nondestructive refusals")
