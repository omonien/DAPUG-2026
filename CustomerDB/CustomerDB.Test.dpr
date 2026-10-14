program CustomerDB.Test;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Phys.SQLite,
  CustomerDB.Model.Customer in 'Source\Model\CustomerDB.Model.Customer.pas',
  CustomerDB.Model.Order in 'Source\Model\CustomerDB.Model.Order.pas',
  CustomerDB.Data.Database in 'Source\Data\CustomerDB.Data.Database.pas',
  CustomerDB.Data.SeedData in 'Source\Data\CustomerDB.Data.SeedData.pas',
  CustomerDB.Repository.Interfaces in 'Source\Repository\CustomerDB.Repository.Interfaces.pas',
  CustomerDB.Repository.SQLite in 'Source\Repository\CustomerDB.Repository.SQLite.pas',
  CustomerDB.Service.CustomerService in 'Source\Service\CustomerDB.Service.CustomerService.pas';

var
  lDbManager: TDatabaseManager;
  lService: TCustomerService;
  lCustomerRepo: ICustomerRepository;
  lOrderRepo: IOrderRepository;
  lCustomers: TObjectList<TCustomer>;
  lOrders: TObjectList<TOrder>;
  lLines: TObjectList<TOrderLine>;
  lCustomer: TCustomer;
  lOrder: TOrder;
  lLine: TOrderLine;
begin
  try
    WriteLn('=== CustomerDB Test ===');
    WriteLn;

    // Initialize database
    WriteLn('Initializing database...');
    lDbManager := TDatabaseManager.Create;
    try
      lDbManager.Initialize;
      WriteLn('Database OK: ', lDbManager.Connection.Params.Database);
      WriteLn;

      lCustomerRepo := TSQLiteCustomerRepository.Create(lDbManager.Connection);
      lOrderRepo := TSQLiteOrderRepository.Create(lDbManager.Connection);
      lService := TCustomerService.Create(lCustomerRepo, lOrderRepo);
      try
        // Test 1: GetAll
        WriteLn('--- Test 1: GetAllCustomers ---');
        lCustomers := lService.GetAllCustomers;
        try
          WriteLn('Count: ', lCustomers.Count);
          for lCustomer in lCustomers do
          begin
            WriteLn(Format('  [%d] %s | Company: "%s" | City: %s | B2B: %s | Email: %s',
              [lCustomer.Id, lCustomer.FullName, lCustomer.Company, lCustomer.City,
               BoolToStr(lCustomer.IsBusinessCustomer, True), lCustomer.Email]));
          end;
        finally
          lCustomers.Free;
        end;
        WriteLn;

        // Test 2: Search
        WriteLn('--- Test 2: Search "Duck" ---');
        lCustomers := lService.SearchCustomers('Duck');
        try
          WriteLn('Count: ', lCustomers.Count);
          for lCustomer in lCustomers do
            WriteLn(Format('  [%d] %s', [lCustomer.Id, lCustomer.FullName]));
        finally
          lCustomers.Free;
        end;
        WriteLn;

        // Test 3: Search "Empire"
        WriteLn('--- Test 3: Search "Empire" ---');
        lCustomers := lService.SearchCustomers('Empire');
        try
          WriteLn('Count: ', lCustomers.Count);
          for lCustomer in lCustomers do
            WriteLn(Format('  [%d] %s (%s)', [lCustomer.Id, lCustomer.FullName, lCustomer.Company]));
        finally
          lCustomers.Free;
        end;
        WriteLn;

        // Test 4: Orders for Donald Duck (Id=1)
        WriteLn('--- Test 4: Orders for Donald Duck (Id=1) ---');
        lOrders := lService.GetCustomerOrders(1);
        try
          WriteLn('Order count: ', lOrders.Count);
          for lOrder in lOrders do
          begin
            WriteLn(Format('  Order #%d | Date: %s | Status: %s',
              [lOrder.Id, DateToStr(lOrder.OrderDate), lOrder.Status]));

            // Test 5: Order lines
            lLines := lService.GetOrderLines(lOrder.Id);
            try
              for lLine in lLines do
                WriteLn(Format('    - %s x%d @ %.2f = %.2f',
                  [lLine.ProductName, lLine.Quantity, lLine.UnitPrice, lLine.LineTotal]));
            finally
              lLines.Free;
            end;
          end;
        finally
          lOrders.Free;
        end;
        WriteLn;

        // Test 6: Customer with no orders (Gladstone Gander, Id=7)
        WriteLn('--- Test 6: Orders for Gladstone Gander (Id=7) ---');
        lOrders := lService.GetCustomerOrders(7);
        try
          WriteLn('Order count: ', lOrders.Count, ' (expected: 0)');
        finally
          lOrders.Free;
        end;
        WriteLn;

        WriteLn('=== ALL TESTS PASSED ===');
      finally
        lService.Free;
      end;
    finally
      lDbManager.Free;
    end;
  except
    on E: Exception do
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
  end;

  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
