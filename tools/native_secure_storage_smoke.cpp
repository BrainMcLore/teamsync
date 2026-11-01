#include <windows.h>
#include <wincred.h>
#include <cassert>
#include <cstring>
#include <iostream>
#include "../client/vendor/flutter_secure_storage_windows/windows/native_string_conversion.h"
#pragma comment(lib, "Advapi32.lib")

int main() {
  const std::string key="teamsync_native_qa_"+std::to_string(GetCurrentProcessId())+"_"+std::to_string(GetTickCount64());
  NativeAnsiToWide target(key.c_str());
  const std::wstring fixture=L"TeamSync QA / проверка";
  CREDENTIALW input{};
  input.Type=CRED_TYPE_GENERIC;
  input.TargetName=target.data();
  input.CredentialBlobSize=static_cast<DWORD>(fixture.size()*sizeof(wchar_t));
  input.CredentialBlob=reinterpret_cast<LPBYTE>(const_cast<wchar_t*>(fixture.data()));
  input.Persist=CRED_PERSIST_SESSION;
  if(!CredWriteW(&input,0)){std::cerr<<"Credential write failed: "<<GetLastError();return 1;}
  PCREDENTIALW read=nullptr;
  bool ok=CredReadW(target.data(),CRED_TYPE_GENERIC,0,&read)!=FALSE;
  if(ok){
    ok=read->CredentialBlobSize==input.CredentialBlobSize&&std::memcmp(read->CredentialBlob,input.CredentialBlob,input.CredentialBlobSize)==0&&std::string(NativeWideToAnsi(read->TargetName))==key;
    CredFree(read);
  }
  const NativeAnsiToWide filter((key+"*").c_str());
  DWORD count=0;PCREDENTIALW* entries=nullptr;
  if(CredEnumerateW(filter.data(),0,&count,&entries)){ok=ok&&count==1;CredFree(entries);}else{ok=false;}
  const bool removed=CredDeleteW(target.data(),CRED_TYPE_GENERIC,0)!=FALSE;
  if(!ok||!removed)return 2;
  std::cout<<"Native credential adapter: Unicode value round trip, key conversion, enumeration and cleanup passed.";
  return 0;
}
