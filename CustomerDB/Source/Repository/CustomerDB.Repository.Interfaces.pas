unit CustomerDB.Repository.Interfaces;

interface

uses
  System.Generics.Collections,
  CustomerDB.Model.Customer,
  CustomerDB.Model.Order;

type
  ICustomerRepository = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetAll: TObjectList<TCustomer>;
    function GetById(aId: Integer): TCustomer;
    function Search(const aFilter: string): TObjectList<TCustomer>;
    function Insert(aCustomer: TCustomer): Integer;
    procedure Update(aCustomer: TCustomer);
    procedure Delete(aId: Integer);
  end;

  IOrderRepository = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function GetByCustomerId(aCustomerId: Integer): TObjectList<TOrder>;
    function GetOrderLines(aOrderId: Integer): TObjectList<TOrderLine>;
  end;

implementation

end.
