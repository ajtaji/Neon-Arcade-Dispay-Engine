; Durable whole-file storage for owned disk images and immutable recording inputs.
; Existing files are opened without creation/truncation and must have exact size.
; CreateNew never replaces a file and removes only its own failed partial output.
; OS flushing lives in Neon. PureBasic's buffer flush can return zero for an
; empty language buffer; this service explicitly checks the OS sync result.
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  ImportC ""
    GLFile_open.l(path.p-utf8, flags.l, mode.l) As "open"
    GLFile_lseek.q(fd.l, offset.q, origin.l) As "lseek"
    GLFile_write.i(fd.l, *bytes, count.i) As "write"
    GLFile_fsync.l(fd.l) As "fsync"
    GLFile_close.l(fd.l) As "close"
    GLFile_unlink.l(path.p-utf8) As "unlink"
    GLFile_errno.i() As "__errno_location"
  EndImport
CompilerEndIf

Procedure.i GL_FileStore(path.s, *bytes, size.q, CreateNew.i = #False)
  Protected handle.i, actual.q, done.q, chunk.i, wrote.i, ok.i = #True
  If path = "" Or size < 0 Or (size And Not *bytes) : ProcedureReturn #False : EndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected disposition.i = #OPEN_EXISTING, written.l
    If CreateNew : disposition = #CREATE_NEW : EndIf
    handle = CreateFile_(path, #GENERIC_WRITE, #FILE_SHARE_READ, 0, disposition, #FILE_ATTRIBUTE_NORMAL, 0)
    If handle = #INVALID_HANDLE_VALUE : ProcedureReturn #False : EndIf
    If Not CreateNew
      If Not GetFileSizeEx_(handle, @actual) Or actual <> size : ok = #False : EndIf
    EndIf
    While ok And done < size
      chunk = 1048576 : If size - done < chunk : chunk = size - done : EndIf
      written = 0
      If Not WriteFile_(handle, *bytes + done, chunk, @written, 0) Or written <= 0
        ok = #False
      Else
        done + written
      EndIf
    Wend
    If ok And Not FlushFileBuffers_(handle) : ok = #False : EndIf
    If Not CloseHandle_(handle) : ok = #False : EndIf
    If Not ok And CreateNew : DeleteFile_(path) : EndIf
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    Protected flags.l = 1 ; O_WRONLY, without O_TRUNC
    If CreateNew : flags | 64 | 128 : EndIf ; O_CREAT | O_EXCL; owner read/write
    handle = GLFile_open(path, flags, 384)
    If handle < 0 : ProcedureReturn #False : EndIf
    If Not CreateNew
      actual = GLFile_lseek(handle, 0, 2)
      If actual <> size Or GLFile_lseek(handle, 0, 0) <> 0 : ok = #False : EndIf
    EndIf
    While ok And done < size
      chunk = 1048576 : If size - done < chunk : chunk = size - done : EndIf
      wrote = GLFile_write(handle, *bytes + done, chunk)
      If wrote > 0
        done + wrote
      ElseIf wrote = 0 Or PeekL(GLFile_errno()) <> 4 ; EINTR retries only write/fsync, never close
        ok = #False
      EndIf
    Wend
    If ok
      Repeat
        wrote = GLFile_fsync(handle)
      Until wrote = 0 Or PeekL(GLFile_errno()) <> 4
      If wrote <> 0 : ok = #False : EndIf
    EndIf
    If GLFile_close(handle) <> 0 : ok = #False : EndIf
    If Not ok And CreateNew : GLFile_unlink(path) : EndIf
  CompilerElse
    ProcedureReturn #False
  CompilerEndIf
  ProcedureReturn ok
EndProcedure
