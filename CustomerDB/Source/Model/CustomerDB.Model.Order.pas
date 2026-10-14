unit CustomerDB.Model.Order;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TOrderLine = class
  private
    FId: Integer;
    FOrderId: Integer;
    FProductName: string;
    FQuantity: Integer;
    FUnitPrice: Double;
  public
    function LineTotal: Double;

    property Id: Integer read FId write FId;
    property OrderId: Integer read FOrderId write FOrderId;
    property ProductName: string read FProductName write FProductName;
    property Quantity: Integer read FQuantity write FQuantity;
    property UnitPrice: Double read FUnitPrice write FUnitPrice;
  end;

  TOrder = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FOrderDate: TDateTime;
    FStatus: string;
    FLines: TObjectList<TOrderLine>;
  public
    constructor Create;
    destructor Destroy; override;
    function OrderTotal: Double;

    property Id: Integer read FId write FId;
    property CustomerId: Integer read FCustomerId write FCustomerId;
    property OrderDate: TDateTime read FOrderDate write FOrderDate;
    property Status: string read FStatus write FStatus;
    property Lines: TObjectList<TOrderLine> read FLines;
  end;

implementation

{ TOrderLine }

function TOrderLine.LineTotal: Double;
begin
  Result := FQuantity * FUnitPrice;
end;

{ TOrder }

constructor TOrder.Create;
begin
  inherited;
  FLines := TObjectList<TOrderLine>.Create(True);
end;

destructor TOrder.Destroy;
begin
  FLines.Free;
  inherited;
end;

function TOrder.OrderTotal: Double;
var
  lLine: TOrderLine;
begin
  Result := 0;
  for lLine in FLines do
    Result := Result + lLine.LineTotal;
end;

end.
