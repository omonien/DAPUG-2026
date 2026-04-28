unit CustomerDB.Data.Database;

interface

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  FireDAC.DApt;

type
  TDatabaseManager = class
  private
    FConnection: TFDConnection;
    FDatabasePath: string;
    procedure CreateSchema;
    procedure SeedData;
    function DatabaseExists: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize;
    property Connection: TFDConnection read FConnection;
  end;

implementation

uses
  CustomerDB.Data.SeedData;

constructor TDatabaseManager.Create;
begin
  inherited;
  FDatabasePath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'CustomerDB.db');
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := FDatabasePath;
  FConnection.Params.Values['LockingMode'] := 'Normal';
  FConnection.LoginPrompt := False;
end;

destructor TDatabaseManager.Destroy;
begin
  FConnection.Free;
  inherited;
end;

function TDatabaseManager.DatabaseExists: Boolean;
begin
  Result := TFile.Exists(FDatabasePath);
end;

procedure TDatabaseManager.Initialize;
var
  lNeedsSeed: Boolean;
begin
  lNeedsSeed := not DatabaseExists;
  FConnection.Connected := True;

  // Always ensure schema exists (CREATE IF NOT EXISTS is idempotent)
  CreateSchema;

  if lNeedsSeed then
    SeedData;
end;

procedure TDatabaseManager.CreateSchema;
begin
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS Customer (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  FirstName TEXT NOT NULL,' +
    '  LastName TEXT NOT NULL,' +
    '  Company TEXT DEFAULT '''',' +
    '  Email TEXT DEFAULT '''',' +
    '  Phone TEXT DEFAULT '''',' +
    '  Address TEXT DEFAULT '''',' +
    '  City TEXT DEFAULT '''',' +
    '  ZipCode TEXT DEFAULT '''',' +
    '  Country TEXT DEFAULT '''',' +
    '  CVR TEXT DEFAULT '''',' +
    '  IsBusinessCustomer INTEGER DEFAULT 0,' +
    '  CreatedAt TEXT DEFAULT CURRENT_TIMESTAMP' +
    ')'
  );

  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS [Order] (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  CustomerId INTEGER NOT NULL,' +
    '  OrderDate TEXT NOT NULL,' +
    '  Status TEXT DEFAULT ''Pending'',' +
    '  FOREIGN KEY (CustomerId) REFERENCES Customer(Id)' +
    ')'
  );

  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS OrderLine (' +
    '  Id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  OrderId INTEGER NOT NULL,' +
    '  ProductName TEXT NOT NULL,' +
    '  Quantity INTEGER DEFAULT 1,' +
    '  UnitPrice REAL NOT NULL,' +
    '  FOREIGN KEY (OrderId) REFERENCES [Order](Id)' +
    ')'
  );
end;

procedure TDatabaseManager.SeedData;
var
  lSeeder: TSeedData;
begin
  lSeeder := TSeedData.Create(FConnection);
  try
    lSeeder.Seed;
  finally
    lSeeder.Free;
  end;
end;

end.
