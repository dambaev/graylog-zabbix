{ mkDerivation
, base, hspec, parsec, stdenv, text, lib
, wai, warp, servant, servant-server, aeson
, stm, stm-chans, transformers
}:

mkDerivation {
  pname = "graylog-zabbix";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    base
    servant
    servant-server
    text
    aeson
    stm
    stm-chans
    transformers
  ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [
    base
    hspec
    text
    servant
    servant-server
    wai
    warp
    aeson
    stm
    stm-chans
    transformers
  ];
  description = "graylog proxy";
  license = lib.licenses.bsd3;
}