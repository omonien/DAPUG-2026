unit CustomerDB.Model.Customer;

interface

uses
  System.SysUtils;

type
  TCustomer = class
  private
    FId: Integer;
    FFirstName: string;
    FLastName: string;
    FCompany: string;
    FEmail: string;
    FPhone: string;
    FAddress: string;
    FCity: string;
    FZipCode: string;
    FCountry: string;
    FCVR: string;
    FIsBusinessCustomer: Boolean;
    FCreatedAt: TDateTime;
  public
    function FullName: string;
    function DisplayName: string;

    property Id: Integer read FId write FId;
    property FirstName: string read FFirstName write FFirstName;
    property LastName: string read FLastName write FLastName;
    property Company: string read FCompany write FCompany;
    property Email: string read FEmail write FEmail;
    property Phone: string read FPhone write FPhone;
    property Address: string read FAddress write FAddress;
    property City: string read FCity write FCity;
    property ZipCode: string read FZipCode write FZipCode;
    property Country: string read FCountry write FCountry;
    property CVR: string read FCvr write FCvr;
    property IsBusinessCustomer: Boolean read FIsBusinessCustomer write FIsBusinessCustomer;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

implementation

function TCustomer.FullName: string;
begin
  Result := Trim(FFirstName + ' ' + FLastName);
end;

function TCustomer.DisplayName: string;
begin
  if FIsBusinessCustomer and (FCompany <> '') then
    Result := FCompany
  else
    Result := FullName;
end;

end.
