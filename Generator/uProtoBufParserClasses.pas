unit uProtoBufParserClasses;

interface

uses
  System.Classes,
  System.Generics.Defaults,
  System.Generics.Collections,
  uProtoBufParserAbstractClasses;

type
  TPropKind = ( //
    ptDefaultOptional, //
    ptRequired, //
    ptOptional, //
    ptRepeated, //
    ptReserved,
    ptOneOf);

  TScalarPropertyType = ( //
    sptComplex, //
    sptDouble, //
    sptFloat, //
    sptInt32, //
    sptInt64, //
    sptuInt32, //
    sptUint64, //
    sptSInt32, //
    sptSInt64, //
    sptFixed32, //
    sptFixed64, //
    sptSFixed32, //
    sptSFixed64, //
    sptBool, //
    sptString, //
    sptBytes);

  TProtoBufPropOption = class(TAbstractProtoBufParserItem)
  private
    FOptionValue: string;
  public
    procedure ParseFromProto(const Proto: string; const ProtoLen: NativeUInt;
      var iPos: integer); override;
    property OptionValue: string read FOptionValue;
  end;

  TProtoBufPropOptions = class(TAbstractProtoBufParserContainer<TProtoBufPropOption>)
  private
    function GetHasValue(const OptionName: string): Boolean;
    function GetValue(const OptionName: string): string;
  public
    procedure ParseFromProto(const Proto: string;
      const ProtoLen: NativeUInt; var iPos: integer); override;
    property HasValue[const OptionName: string]: Boolean read GetHasValue;
    property Value[const OptionName: string]: string read GetValue;
  end;

  TProtoBufProperty = class(TAbstractProtoBufParserItem)
  strict private
    FPropFieldNum: integer;
    FPropType: string;
    FPropKind: TPropKind;
    FPropOptions: TProtoBufPropOptions;
    FOneOfPropertyParent: TProtoBufProperty;
  public
    constructor Create(ARoot: TAbstractProtoBufParserItem); override;
    destructor Destroy; override;

    procedure ParseFromProto(const Proto: string; const ProtoLen: NativeUInt;
      var iPos: integer); override;

    property PropKind: TPropKind read FPropKind;
    property PropType: string read FPropType;
    property PropFieldNum: integer read FPropFieldNum;
    property PropOptions: TProtoBufPropOptions read FPropOptions;
    property OneOfPropertyParent: TProtoBufProperty read FOneOfPropertyParent write FOneOfPropertyParent;
  end;

  TProtoBufEnumValue = class(TAbstractProtoBufParserItem)
  strict private
    FValue: integer;
    FIsHexValue: Boolean;
  public
    procedure ParseFromProto(const Proto: string; const ProtoLen: NativeUInt;
      var iPos: integer); override;

    property Value: integer read FValue;
    property IsHexValue: Boolean read FIsHexValue;
  end;

  TProtoBufEnum = class(TAbstractProtoBufParserContainer<TProtoBufEnumValue>)
  strict private
    FAllowAlias: Boolean;
    FHexFormatString: string;
  public
    procedure ParseFromProto(const Proto: string; const ProtoLen: NativeUInt;
      var iPos: integer); override;

    function GetEnumValueString(AEnumIndex: Integer): string;

    property AllowAlias: Boolean read FAllowAlias;
  end;

  TProtoBufMessage = class(TAbstractProtoBufParserContainer<TProtoBufProperty>)
  public
    procedure ParseFromProto(const Proto: string; const ProtoLen: NativeUInt;
      var iPos: integer); override;

    function HasPropertyOfType(const APropType: string): Boolean;
  end;

  TProtoBufEnumList = class(TObjectList<TProtoBufEnum>)
  public
    function FindByName(const EnumName: string): TProtoBufEnum;
  end;

  TProtoBufMessageList = class(TObjectList<TProtoBufMessage>)
  public
    function FindByName(const MessageName: string): TProtoBufMessage;
  end;

  TProtoSyntaxVersion = (psv2, psv3);

  TProtoFile = class(TAbstractProtoBufParserItem)
  strict private
    FProtoBufMessages: TProtoBufMessageList;
    FProtoBufEnums: TProtoBufEnumList;

    FInImportCounter: integer;
    FFileName: string;
    FImports: TStrings;
    FProtoSyntaxVersion: TProtoSyntaxVersion;

    procedure ImportFromProtoFile(const AFileName: string);
  private
    procedure SetFileName(const Value: string);
  public
    constructor Create(ARoot: TAbstractProtoBufParserItem); override;
    destructor Destroy; override;

    procedure ParseEnum(const Proto: string;
      const ProtoLen: NativeUInt; var iPos: integer; Comments: TStringList);
    procedure ParseMessage(const Proto: string;
      const ProtoLen: NativeUInt; var iPos: integer; Comments: TStringList;
      IsExtension: Boolean = False);

    procedure ParseFromProto(const Proto: string; const ProtoLen: NativeUInt;
      var iPos: integer); override;

    property Imports: TStrings read FImports;
    property ProtoBufEnums: TProtoBufEnumList read FProtoBufEnums;
    property ProtoBufMessages: TProtoBufMessageList read FProtoBufMessages;

    property FileName: string read FFileName write SetFileName;
    property ProtoSyntaxVersion: TProtoSyntaxVersion read FProtoSyntaxVersion;
  end;

function StrToPropertyType(const AStr: string): TScalarPropertyType;

implementation

uses
  Math,
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  Winapi.Windows,
  System.Character;

function PropKindToStr(APropKind: TPropKind): string;
begin
  case APropKind of
    ptDefaultOptional:
      Result := '';
    ptRequired:
      Result := 'required';
    ptOptional:
      Result := 'optional';
    ptRepeated:
      Result := 'repeated';
    ptReserved:
      Result := 'reserved';
    ptOneOf:
      Result := 'oneof';
  end;
end;

function StrToPropKind(const AStr: string): TPropKind;
var
  i: TPropKind;
begin
  Result := Low(TPropKind);
  for i := Low(TPropKind) to High(TPropKind) do
    if SameStr(PropKindToStr(i), AStr) then
      begin
        Result := i;
        Break;
      end;
end;

function PropertyTypeToStr(PropType: TScalarPropertyType): string;
begin
  Result := '';
  case PropType of
    sptComplex:
      ;
    sptDouble:
      Result := 'double';
    sptFloat:
      Result := 'float';
    sptInt32:
      Result := 'int32';
    sptInt64:
      Result := 'int64';
    sptuInt32:
      Result := 'uint32';
    sptUint64:
      Result := 'uint64';
    sptSInt32:
      Result := 'sint32';
    sptSInt64:
      Result := 'sint64';
    sptFixed32:
      Result := 'fixed32';
    sptFixed64:
      Result := 'fixed64';
    sptSFixed32:
      Result := 'sfixed32';
    sptSFixed64:
      Result := 'sfixed64';
    sptBool:
      Result := 'bool';
    sptString:
      Result := 'string';
    sptBytes:
      Result := 'bytes';
  end;
end;

function StrToPropertyType(const AStr: string): TScalarPropertyType;
var
  i: TScalarPropertyType;
begin
  Result := Low(TScalarPropertyType);
  for i := Low(TScalarPropertyType) to High(TScalarPropertyType) do
    if SameStr(PropertyTypeToStr(i), AStr) then
      begin
        Result := i;
        Break;
      end;
end;

{ TProtoBufProperty }

constructor TProtoBufProperty.Create(ARoot: TAbstractProtoBufParserItem);
begin
  inherited;
  FPropOptions := TProtoBufPropOptions.Create(ARoot);
end;

destructor TProtoBufProperty.Destroy;
begin
  FreeAndNil(FPropOptions);
  inherited;
end;

procedure SkipWhitespaces(const Proto: string; const ProtoLen: NativeUInt;
  var iPos: integer; ASkipParagraphSeparator: Boolean = True);
begin
  while (iPos <= ProtoLen) and Proto[iPos].IsWhiteSpace do
  begin
    if not ASkipParagraphSeparator then
    begin
      if UCS4Char(Proto[iPos]) < $FF then //IsLatin1, not accessible
      begin
        if Proto[iPos].IsInArray([#13, #10]) then
          Break;
      end else
        if Proto[iPos].GetUnicodeCategory = TUnicodeCategory.ucParagraphSeparator then
          Break;
    end;
    Inc(iPos);
  end;
end;

function ReadAllTillChar(const Proto: string; const ProtoLen: NativeUInt;
  var iPos: integer; BreakSymbol: array of Char): string;
begin
  Result := '';
  while (iPos <= ProtoLen) and not Proto[iPos].IsInArray(BreakSymbol) do
    begin
      Result := Result + Proto[iPos];
      Inc(iPos);
    end;
end;

function ReadAllToEOL(const Proto: string; const ProtoLen: NativeUInt;
  var iPos: integer): string;
begin
  Result := ReadAllTillChar(Proto, ProtoLen, iPos, [#13, #10]);
end;

procedure ReadCommentIfExists(ADestList: TStrings; AMultiLine: Boolean;
  const Proto: string; const ProtoLen: NativeUInt; var iPos: integer);
var
  s: string;
begin
  SkipWhitespaces(Proto, ProtoLen, iPos, False);
  while (iPos < ProtoLen - 1) and (Proto[iPos] = '/') and (Proto[iPos + 1] = '/') do
    begin
      Inc(iPos, 2);
      SkipWhitespaces(Proto, ProtoLen, iPos, False);
      s:= ReadAllToEOL(Proto, ProtoLen, iPos);
      if Length(s) > 0 then
        ADestList.Add(s);
      //since we've Read to EOL, this will skip the EOL, if allowed
      if AMultiLine then
        SkipWhitespaces(Proto, ProtoLen, iPos);
    end;
end;

procedure SkipAllComments(const Proto: string; const ProtoLen: NativeUInt;
  var iPos: integer);
begin
  while True do
  begin
    SkipWhitespaces(Proto, ProtoLen, iPos);
    if (iPos < ProtoLen - 1) and (Proto[iPos] = '/') and (Proto[iPos + 1] = '/') then
      ReadAllToEOL(Proto, ProtoLen, iPos) else
      Break;
  end;
  SkipWhitespaces(Proto, ProtoLen, iPos);
end;

procedure SkipRequiredChar(const Proto: string; const ProtoLen: NativeUInt;
  var iPos: integer; const RequiredChar: Char);
begin
  SkipWhitespaces(Proto, ProtoLen, iPos);
  if (iPos > ProtoLen) or (Proto[iPos] <> RequiredChar) then
    raise EParserError.Create(RequiredChar + ' not found in ProtoBuf');
  Inc(iPos);
end;

function ReadWordFromBuf(const Proto: string; const ProtoLen: NativeUInt;
  var iPos: integer; BreakSymbols: array of Char): string;
begin
  SkipWhitespaces(Proto, ProtoLen, iPos);

  Result := '';
  while (iPos <= ProtoLen) and not Proto[iPos].IsWhiteSpace and not Proto[iPos].IsInArray(BreakSymbols) do
    begin
      Result := Result + Proto[iPos];
      Inc(iPos);
    end;
end;

procedure TProtoBufProperty.ParseFromProto(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer);
var
  Buf: string;
  tmpOption: TProtoBufPropOption;
begin
  inherited;
  FPropOptions.Clear;
  FComments.Clear;
  {
    [optional] int32   DefField1  = 1  [default = 2]; // def field 1, default value 2
    int64 DefField2 = 2;
  }
  Buf := ReadWordFromBuf(Proto, ProtoLen, iPos, []);
  // in Buf - first word of property. Choose type
  FPropKind := StrToPropKind(Buf);
  if FPropKind = ptReserved then
    begin
      ReadAllTillChar(Proto, ProtoLen, iPos, [';']);
      SkipRequiredChar(Proto, ProtoLen, iPos, ';');
      exit; // reserved is not supported now by this parser
    end;
  if FPropKind <> ptDefaultOptional then // if required/optional/repeated is not skipped,
    Buf := ReadWordFromBuf(Proto, ProtoLen, iPos, []); // read type of property

  FPropType := Buf;

  if FPropKind = ptOneOf then
  begin
    FName := FPropType;
    // skip '{' character
    SkipRequiredChar(Proto, ProtoLen, iPos, '{');
  end else
  begin
    FName := ReadWordFromBuf(Proto, ProtoLen, iPos, ['=']);

    // skip '=' character
    SkipRequiredChar(Proto, ProtoLen, iPos, '=');

    // read property tag
    Buf := ReadWordFromBuf(Proto, ProtoLen, iPos, [';', '[']);
    FPropFieldNum := StrToInt(Buf);
    SkipWhitespaces(Proto, ProtoLen, iPos);
    if Proto[iPos] = '[' then
      FPropOptions.ParseFromProto(Proto, ProtoLen, iPos);

    if Assigned(FRoot) then
      if TProtoFile(FRoot).ProtoSyntaxVersion = psv3 then
        if not FPropOptions.HasValue['packed'] then
          begin
            tmpOption := TProtoBufPropOption.Create(FRoot);
            FPropOptions.Add(tmpOption);
            tmpOption.Name := 'packed';
            tmpOption.FOptionValue := 'true';
          end;

    // read separator
    SkipRequiredChar(Proto, ProtoLen, iPos, ';');
  end;

  ReadCommentIfExists(FComments, False, Proto, ProtoLen, iPos);
end;

{ TProtoBufPropOption }

procedure TProtoBufPropOption.ParseFromProto(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer);
begin
  inherited;
  { [default = Val2, packed = true]; }
  SkipWhitespaces(Proto, ProtoLen, iPos);
  FName := ReadWordFromBuf(Proto, ProtoLen, iPos, ['=']);

  // skip '=' character
  SkipRequiredChar(Proto, ProtoLen, iPos, '=');

  SkipWhitespaces(Proto, ProtoLen, iPos);
  if (iPos <= ProtoLen) and (Proto[iPos] <> '"') then
    FOptionValue := ReadWordFromBuf(Proto, ProtoLen, iPos, [',', ']'])
  else
    begin
      Inc(iPos);
      { TODO : Solve problem with double "" in the middle of string... }
      FOptionValue := Trim('"' + ReadAllTillChar(Proto, ProtoLen, iPos, [',', ']', #13, #10]));
      if not EndsStr('"', FOptionValue) then
        raise EParserError.Create('no string escape in property ' + Name);
      // SkipRequiredChar(Proto, iPos, '"');
    end;

  SkipWhitespaces(Proto, ProtoLen, iPos);
  if (iPos <= ProtoLen) and (Proto[iPos] = ',') then
    Inc(iPos);
end;

{ TProtoBufPropOptions }

function TProtoBufPropOptions.GetHasValue(const OptionName: string): Boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to Count - 1 do
    if Items[i].Name = OptionName then
      begin
        Result := True;
        Break;
      end;
end;

function TProtoBufPropOptions.GetValue(const OptionName: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to Count - 1 do
    if Items[i].Name = OptionName then
      begin
        Result := Items[i].OptionValue;
        Break;
      end;
end;

procedure TProtoBufPropOptions.ParseFromProto(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer);
var
  Option: TProtoBufPropOption;
begin
  inherited;
  SkipRequiredChar(Proto, ProtoLen, iPos, '[');
  SkipWhitespaces(Proto, ProtoLen, iPos); // check for empty options
  while (iPos <= ProtoLen) and (Proto[iPos] <> ']') do
    begin
      Option := TProtoBufPropOption.Create(FRoot);
      try
        Option.ParseFromProto(Proto, ProtoLen, iPos);
        Add(Option);
        Option := nil;
        SkipWhitespaces(Proto, ProtoLen, iPos);
      finally
        Option.Free;
      end;
    end;
  SkipRequiredChar(Proto, ProtoLen, iPos, ']');
end;

{ TProtoBufEnumValue }

procedure TProtoBufEnumValue.ParseFromProto(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer);
var
  s: string;
begin
  inherited;
  { Val1 = 1; }
  FComments.Clear;
  FName := ReadWordFromBuf(Proto, ProtoLen, iPos, ['=']);
  if Length(FName) = 0 then
    raise EParserError.Create('Enumeration contains unnamed value');
  SkipRequiredChar(Proto, ProtoLen, iPos, '=');
  s:= ReadWordFromBuf(Proto, ProtoLen, iPos, [';']);
  FValue := StrToInt(s);
  FIsHexValue:= Pos('0x', s) = 1;
  SkipRequiredChar(Proto, ProtoLen, iPos, ';');
  ReadCommentIfExists(FComments, False, Proto, ProtoLen, iPos);
end;

{ TProtoBufEnum }

function TProtoBufEnum.GetEnumValueString(AEnumIndex: Integer): string;
var
  item: TProtoBufEnumValue;
begin
  item:= Items[AEnumIndex];
  if item.isHexValue then
    Result:= Format(FHexFormatString, [item.Value]) else
    Result:= IntToStr(item.Value);
end;

procedure TProtoBufEnum.ParseFromProto(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer);
var
  Item: TProtoBufEnumValue;
  lPos, lMaxValue: Integer;
  sOptionPeek, sOptionValue: string;
  TempComments: TStringList;
begin
  inherited;
  (* Enum1 {
    Val1 = 1;
    Val2 = 2;
    } *)

  lMaxValue:= 0;
  FName := ReadWordFromBuf(Proto, ProtoLen, iPos, ['{']);
  SkipRequiredChar(Proto, ProtoLen, iPos, '{');
  TempComments:= TStringList.Create;
  try
    TempComments.TrailingLineBreak:= False;
    while (iPos <= ProtoLen) and (Proto[iPos] <> '}') do
      begin
        TempComments.Clear;
        SkipWhitespaces(Proto, ProtoLen, iPos);
        ReadCommentIfExists(TempComments, True, Proto, ProtoLen, iPos);
        if (iPos <= ProtoLen) and (Proto[iPos] = '}') then //after reading comments, the enum might prematurly end
          Continue;

        lPos:= iPos;
        sOptionPeek:= ReadWordFromBuf(Proto, ProtoLen, lPos, [';']);
        if SameText(sOptionPeek, 'option') then
        begin
          iPos:= lPos;
          sOptionPeek:= ReadWordFromBuf(Proto, ProtoLen, iPos, [';']);
          SkipRequiredChar(Proto, ProtoLen, iPos, '=');
          sOptionValue:= ReadWordFromBuf(Proto, ProtoLen, iPos, [';']);
          if SameText(sOptionPeek, 'allow_alias') then
            FAllowAlias:= SameText(sOptionValue, 'true') else
            raise EParserError.CreateFmt('Unknown option %s while parsing enum %s', [sOptionPeek, FName]);
          SkipRequiredChar(Proto, ProtoLen, iPos, ';');
        end else
        begin
          Item := TProtoBufEnumValue.Create(FRoot);
          try
            Item.ParseFromProto(Proto, ProtoLen, iPos);
            Item.AddCommentsToBeginning(TempComments);
            Add(Item);
            lMaxValue:= Max(lMaxValue, Item.Value);
            Item := nil;
            SkipWhitespaces(Proto, ProtoLen, iPos);
          finally
            Item.Free;
          end;
        end;
      end;
  finally
    TempComments.Free;
  end;
  SkipRequiredChar(Proto, ProtoLen, iPos, '}');
  ReadCommentIfExists(FComments, False, Proto, ProtoLen, iPos);

  if lMaxValue < 256 then
    FHexFormatString:= '$%.2x' else
    if lMaxValue < 65536 then
      FHexFormatString:= '$%.4x' else
      FHexFormatString:= '$%.8x';

  Sort(TComparer<TProtoBufEnumValue>.Construct(
    function(const Left, Right: TProtoBufEnumValue): integer
    begin
      Result := Left.Value - Right.Value;
    end));
end;

{ TProtoBufMessage }

function TProtoBufMessage.HasPropertyOfType(const APropType: string): Boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to Count - 1 do
    if Items[i].PropType = APropType then
      begin
        Result := True;
        Break;
      end;
end;

procedure TProtoBufMessage.ParseFromProto(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer);
var
  Item, OneOfPropertyParent: TProtoBufProperty;
  TempComments: TStringList;
begin
  inherited;
  (*
    TestMsg0 {
    required int32 Field1 = 1;
    required int64 Field2 = 2;
    }
  *)
  ReadCommentIfExists(FComments, True, Proto, ProtoLen, iPos);
  OneOfPropertyParent:= nil;
  FName := ReadWordFromBuf(Proto, ProtoLen, iPos, ['{']);
  ReadCommentIfExists(FComments, True, Proto, ProtoLen, iPos);
  SkipRequiredChar(Proto, ProtoLen, iPos, '{');
  TempComments:= TStringList.Create;
  try
    TempComments.TrailingLineBreak:= False;
    while (iPos <= ProtoLen) and ((Proto[iPos] <> '}') or (OneOfPropertyParent <> nil)) do
      begin
        if (OneOfPropertyParent <> nil) and (Proto[iPos] = '}') then
        begin
          SkipRequiredChar(Proto, ProtoLen, iPos, '}');
          SkipWhitespaces(Proto, ProtoLen, iPos);
          ReadCommentIfExists(OneOfPropertyParent.Comments, False, Proto, ProtoLen, iPos);
          OneOfPropertyParent:= nil;
          SkipWhitespaces(Proto, ProtoLen, iPos);
          Continue;
        end;
        TempComments.Clear;
        SkipWhitespaces(Proto, ProtoLen, iPos);
        ReadCommentIfExists(TempComments, True, Proto, ProtoLen, iPos);
        if (iPos <= ProtoLen) and (Proto[iPos] = '}') then //after reading comments, the message might prematurly end
          Continue;
        if PosEx('enum', Proto, iPos) = iPos then
          begin
            Inc(iPos, Length('enum'));
            if FRoot is TProtoFile then
              begin
                TProtoFile(FRoot).ParseEnum(Proto, ProtoLen, iPos, TempComments);
                Continue;
              end;
          end;
        if PosEx('message', Proto, iPos) = iPos then
          begin
            Inc(iPos, Length('message'));
            if FRoot is TProtoFile then
              begin
                TProtoFile(FRoot).ParseMessage(Proto, ProtoLen, iPos, TempComments);
                Continue;
              end;
          end;

        Item := TProtoBufProperty.Create(FRoot);
        try
          Item.ParseFromProto(Proto, ProtoLen, iPos);
          Item.OneOfPropertyParent:= OneOfPropertyParent;
          Item.AddCommentsToBeginning(TempComments);
          Add(Item);
          if Item.PropKind = ptOneOf then
          begin
            if OneOfPropertyParent <> nil then
              raise EParserError.CreateFmt('Unsupported nested oneof property %s within %s', [Item.FName, OneOfPropertyParent.Name]);
            OneOfPropertyParent:= Item;
          end;
          Item := nil;
          SkipWhitespaces(Proto, ProtoLen, iPos);
        finally
          Item.Free;
        end;
      end;
  finally
    TempComments.Free;
  end;
  SkipRequiredChar(Proto, ProtoLen, iPos, '}');
  ReadCommentIfExists(FComments, False, Proto, ProtoLen, iPos);

  //do NOT sort field definitions by FieldNumber; order is important for OneOf,
  //also better to keep order of declaration the same as in .proto file
end;

{ TProtoFile }

constructor TProtoFile.Create(ARoot: TAbstractProtoBufParserItem);
begin
  inherited;
  FImports := TStringList.Create;
  FProtoBufMessages := TProtoBufMessageList.Create;
  FProtoBufEnums := TProtoBufEnumList.Create;
end;

destructor TProtoFile.Destroy;
begin
  FreeAndNil(FProtoBufEnums);
  FreeAndNil(FProtoBufMessages);
  FreeAndNil(FImports);
  inherited;
end;

function PathRelativePathTo(pszPath: PChar; pszFrom: PChar; dwAttrFrom: DWORD; pszTo: PChar; dwAtrTo: DWORD): LongBool; stdcall; external 'shlwapi.dll' Name 'PathRelativePathToW';
function PathCanonicalize(lpszDst: PChar; lpszSrc: PChar): LongBool; stdcall; external 'shlwapi.dll' Name 'PathCanonicalizeW';

function AbsToRel(const AbsPath, BasePath: string): string;
var
  Path: array [0 .. MAX_PATH - 1] of Char;
begin
  PathRelativePathTo(@Path[0], PChar(BasePath), FILE_ATTRIBUTE_DIRECTORY, PChar(AbsPath), 0);
  Result := Path;
end;

function RelToAbs(const RelPath, BasePath: string): string;
var
  Dst: array [0 .. MAX_PATH - 1] of Char;
begin
  if TPath.IsRelativePath(RelPath) then
    begin
      PathCanonicalize(@Dst[0], PChar(IncludeTrailingPathDelimiter(BasePath) + RelPath));
      Result := Dst;
    end
  else
    Result := RelPath;
end;

procedure TProtoFile.ImportFromProtoFile(const AFileName: string);
var
  SL: TStringList;
  iPos: integer;
  OldFileName: string;
  OldName: string;
  sFileName, sProto: string;
begin
  if FFileName = '' then
    raise EParserError.CreateFmt('Cant import from %s, because source .proto file name not specified', [AFileName]);
  Inc(FInImportCounter);
  try
    SL := TStringList.Create;
    try
      sFileName := RelToAbs(AFileName, ExtractFilePath(FFileName));
      SL.LoadFromFile(sFileName);

      OldFileName := FFileName;
      OldName := FName;
      try
        FileName := sFileName;
        iPos := 1;
        sProto:= SL.Text;
        ParseFromProto(sProto, Length(sProto), iPos);
        FImports.Add(FName);
      finally
        FFileName := OldFileName;
        FName := OldName;
      end;
    finally
      SL.Free;
    end;
  finally
    Dec(FInImportCounter);
  end;
end;

procedure TProtoFile.ParseEnum(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer; Comments: TStringList);
var
  Enum: TProtoBufEnum;
begin
  Enum := TProtoBufEnum.Create(Self);
  try
    Enum.IsImported := FInImportCounter > 0;
    Enum.ParseFromProto(Proto, ProtoLen, iPos);
    Enum.AddCommentsToBeginning(Comments);
    FProtoBufEnums.Add(Enum);
    Enum := nil;
  finally
    Enum.Free;
  end;
end;

procedure TProtoFile.ParseFromProto(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer);
var
  Buf: string;
  i, j: integer;
  TempComments: TStringList;
begin
  // need skip comments,
  // parse .proto package name
  TempComments:= TStringList.Create;
  try
    TempComments.TrailingLineBreak:= False;
    while iPos < ProtoLen do
      begin
        SkipWhitespaces(Proto, ProtoLen, iPos);
        ReadCommentIfExists(TempComments, True, Proto, ProtoLen, iPos);
        SkipWhitespaces(Proto, ProtoLen, iPos);
        Buf := ReadWordFromBuf(Proto, ProtoLen, iPos, []);

        if Buf = 'package' then
          begin
            FName := ReadWordFromBuf(Proto, ProtoLen, iPos, [';']);
            SkipRequiredChar(Proto, ProtoLen, iPos, ';');
            TempComments.Clear;
          end;

        if Buf = 'syntax' then
          begin
            SkipRequiredChar(Proto, ProtoLen, iPos, '=');
            Buf := Trim(ReadWordFromBuf(Proto, ProtoLen, iPos, [';']));
            SkipRequiredChar(Proto, ProtoLen, iPos, ';');
            if Buf = '"proto3"' then
              FProtoSyntaxVersion := psv3;
            TempComments.Clear;
          end;

        if Buf = 'import' then
          begin
            Buf := Trim(ReadAllTillChar(Proto, ProtoLen, iPos, [';']));
            ImportFromProtoFile(AnsiDequotedStr(Buf, '"'));
            SkipRequiredChar(Proto, ProtoLen, iPos, ';');
            TempComments.Clear;
          end;

        if Buf = 'enum' then
        begin
          ParseEnum(Proto, ProtoLen, iPos, TempComments);
          TempComments.Clear;
        end;

        if Buf = 'message' then
        begin
          ParseMessage(Proto, ProtoLen, iPos, TempComments);
          TempComments.Clear;
        end;
        if Buf = 'extend' then
        begin
          ParseMessage(Proto, ProtoLen, iPos, TempComments, True);
          TempComments.Clear;
        end;
      end;
  finally
    TempComments.Free;
  end;

  // can`t use QuickSort because of .proto items order
  for i := 0 to FProtoBufMessages.Count - 1 do
    for j := i + 1 to FProtoBufMessages.Count - 1 do
      begin
        if FProtoBufMessages[i].HasPropertyOfType(FProtoBufMessages[j].Name) then
          FProtoBufMessages.Exchange(i, j);
      end;
end;

procedure TProtoFile.ParseMessage(const Proto: string;
  const ProtoLen: NativeUInt; var iPos: integer; Comments: TStringList;
  IsExtension: Boolean);
var
  Msg: TProtoBufMessage;
  i: integer;
begin
  Msg := TProtoBufMessage.Create(Self);
  try
    Msg.IsImported := FInImportCounter > 0;
    Msg.ParseFromProto(Proto, ProtoLen, iPos);
    if IsExtension then
      begin
        for i := 1 to High(integer) do
          if FProtoBufMessages.FindByName(Msg.Name + 'Extension' + IntToStr(i)) = nil then
            begin
              Msg.ExtendOf := Msg.Name;
              Msg.Name := Msg.Name + 'Extension' + IntToStr(i);
              Break;
            end;
      end;
    Msg.AddCommentsToBeginning(Comments);
    FProtoBufMessages.Add(Msg);
    Msg := nil;
  finally
    Msg.Free;
  end;
end;

procedure TProtoFile.SetFileName(const Value: string);
begin
  FFileName := Value;
  FName := ChangeFileExt(ExtractFileName(Value), '');
end;

{ TProtoBufMessageList }

function TProtoBufMessageList.FindByName(const MessageName: string): TProtoBufMessage;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].Name = MessageName then
      begin
        Result := Items[i];
        Break;
      end;
end;

{ TProtoBufEnumList }

function TProtoBufEnumList.FindByName(const EnumName: string): TProtoBufEnum;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].Name = EnumName then
      begin
        Result := Items[i];
        Break;
      end;
end;

end.
