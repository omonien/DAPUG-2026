unit CustomerDB.Service.CustomerService;

interface

uses
  System.Generics.Collections,
  CustomerDB.Model.Customer,
  CustomerDB.Model.Order,
  CustomerDB.Repository.Interfaces;

type
  TCustomerService = class
  private
    FCustomerRepo: ICustomerRepository;
    FOrderRepo: IOrderRepository;
  public
    constructor Create(aCustomerRepo: ICustomerRepository; aOrderRepo: IOrderRepository);

    function GetAllCustomers: TObjectList<TCustomer>;
    function SearchCustomers(const aFilter: string): TObjectList<TCustomer>;
    function GetCustomerById(aId: Integer): TCustomer;
    function GetCustomerOrders(aCustomerId: Integer): TObjectList<TOrder>;
    function GetOrderLines(aOrderId: Integer): TObjectList<TOrderLine>;
    function CreateCustomer(aCustomer: TCustomer): Integer;
    procedure UpdateCustomer(aCustomer: TCustomer);
    procedure DeleteCustomer(aId: Integer);
  end;

implementation

constructor TCustomerService.Create(aCustomerRepo: ICustomerRepository;
  aOrderRepo: IOrderRepository);
begin
  inherited Create;
  FCustomerRepo := aCustomerRepo;
  FOrderRepo := aOrderRepo;
end;

function TCustomerService.GetAllCustomers: TObjectList<TCustomer>;
begin
  Result := FCustomerRepo.GetAll;
end;

function TCustomerService.SearchCustomers(const aFilter: string): TObjectList<TCustomer>;
begin
  Result := FCustomerRepo.Search(aFilter);
end;

function TCustomerService.GetCustomerById(aId: Integer): TCustomer;
begin
  Result := FCustomerRepo.GetById(aId);
end;

function TCustomerService.GetCustomerOrders(aCustomerId: Integer): TObjectList<TOrder>;
begin
  Result := FOrderRepo.GetByCustomerId(aCustomerId);
end;

function TCustomerService.GetOrderLines(aOrderId: Integer): TObjectList<TOrderLine>;
begin
  Result := FOrderRepo.GetOrderLines(aOrderId);
end;

function TCustomerService.CreateCustomer(aCustomer: TCustomer): Integer;
begin
  Result := FCustomerRepo.Insert(aCustomer);
  aCustomer.Id := Result;
end;

procedure TCustomerService.UpdateCustomer(aCustomer: TCustomer);
begin
  FCustomerRepo.Update(aCustomer);
end;

procedure TCustomerService.DeleteCustomer(aId: Integer);
begin
  FCustomerRepo.Delete(aId);
end;

end.
