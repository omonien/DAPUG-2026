unit CustomerDB.Data.SeedData;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client;

type
  TSeedData = class
  private
    FConnection: TFDConnection;
    procedure InsertCustomer(const aFirstName, aLastName, aCompany, aEmail,
      aPhone, aCity, aCountry, aCVR: string; aIsBusiness: Boolean);
    procedure InsertOrder(aCustomerId: Integer; const aDate, aStatus: string);
    procedure InsertOrderLine(aOrderId: Integer; const aProduct: string;
      aQty: Integer; aPrice: Double);
  public
    constructor Create(aConnection: TFDConnection);
    procedure Seed;
  end;

implementation

constructor TSeedData.Create(aConnection: TFDConnection);
begin
  inherited Create;
  FConnection := aConnection;
end;

procedure TSeedData.InsertCustomer(const aFirstName, aLastName, aCompany,
  aEmail, aPhone, aCity, aCountry, aCVR: string; aIsBusiness: Boolean);
begin
  FConnection.ExecSQL(
    'INSERT INTO Customer (FirstName, LastName, Company, Email, Phone, City, Country, CVR, IsBusinessCustomer) ' +
    'VALUES (:fn, :ln, :co, :em, :ph, :ci, :ct, :cvr, :biz)',
    [aFirstName, aLastName, aCompany, aEmail, aPhone, aCity, aCountry, aCVR, Ord(aIsBusiness)]);
end;

procedure TSeedData.InsertOrder(aCustomerId: Integer; const aDate, aStatus: string);
begin
  FConnection.ExecSQL(
    'INSERT INTO [Order] (CustomerId, OrderDate, Status) VALUES (:cid, :dt, :st)',
    [aCustomerId, aDate, aStatus]);
end;

procedure TSeedData.InsertOrderLine(aOrderId: Integer; const aProduct: string;
  aQty: Integer; aPrice: Double);
begin
  FConnection.ExecSQL(
    'INSERT INTO OrderLine (OrderId, ProductName, Quantity, UnitPrice) VALUES (:oid, :pn, :qty, :up)',
    [aOrderId, aProduct, aQty, aPrice]);
end;

procedure TSeedData.Seed;
begin
  // --- Customers (Duck family - private) ---
  InsertCustomer('Donald', 'Duck', '', 'donald@duckburg.com', '555-0101', 'Duckburg', 'USA', '', False);
  InsertCustomer('Daisy', 'Duck', '', 'daisy@duckburg.com', '555-0102', 'Duckburg', 'USA', '', False);
  InsertCustomer('Scrooge', 'McDuck', '', 'scrooge@moneybins.com', '555-0103', 'Duckburg', 'USA', '', False);
  InsertCustomer('Huey', 'Duck', '', 'huey@juniorwoodchucks.com', '555-0104', 'Duckburg', 'USA', '', False);
  InsertCustomer('Dewey', 'Duck', '', 'dewey@juniorwoodchucks.com', '555-0105', 'Duckburg', 'USA', '', False);
  InsertCustomer('Louie', 'Duck', '', 'louie@juniorwoodchucks.com', '555-0106', 'Duckburg', 'USA', '', False);
  InsertCustomer('Gladstone', 'Gander', '', 'lucky@duckburg.com', '555-0107', 'Duckburg', 'USA', '', False);
  InsertCustomer('Gyro', 'Gearloose', '', 'gyro@inventions.com', '555-0108', 'Duckburg', 'USA', '', False);

  // --- Customers (Star Wars companies - business) ---
  InsertCustomer('Sheev', 'Palpatine', 'Galactic Empire Inc.', 'emperor@empire.gal', '555-0201', 'Coruscant', 'Galaxy', '12345678', True);
  InsertCustomer('Han', 'Solo', 'Solo Shipping Co.', 'han@millenniumfalcon.gal', '555-0202', 'Corellia', 'Galaxy', '23456789', True);
  InsertCustomer('Lando', 'Calrissian', 'Cloud City Mining Corp.', 'lando@cloudcity.gal', '555-0203', 'Bespin', 'Galaxy', '34567890', True);
  InsertCustomer('Jabba', 'Hutt', 'Hutt Cartel Enterprises', 'jabba@tattooine.gal', '555-0204', 'Tatooine', 'Galaxy', '45678901', True);
  InsertCustomer('Bail', 'Organa', 'Alderaan Royal Exports', 'bail@alderaan.gal', '555-0205', 'Alderaan', 'Galaxy', '56789012', True);
  InsertCustomer('Hondo', 'Ohnaka', 'Ohnaka Gang Trading', 'hondo@pirates.gal', '555-0206', 'Florrum', 'Galaxy', '67890123', True);

  // --- Orders for Donald Duck (Id=1) ---
  InsertOrder(1, '2025-12-15', 'Delivered');
  InsertOrder(1, '2026-01-20', 'Shipped');
  InsertOrder(1, '2026-03-10', 'Pending');

  // --- Orders for Scrooge McDuck (Id=3) ---
  InsertOrder(3, '2025-11-01', 'Delivered');
  InsertOrder(3, '2026-02-14', 'Delivered');

  // --- Orders for Galactic Empire Inc. (Id=9) ---
  InsertOrder(9, '2026-01-05', 'Delivered');
  InsertOrder(9, '2026-04-01', 'Pending');

  // --- Orders for Solo Shipping Co. (Id=10) ---
  InsertOrder(10, '2026-02-28', 'Shipped');

  // --- Orders for Huey Duck (Id=4) ---
  InsertOrder(4, '2026-03-15', 'Pending');

  // --- Order lines for Donald's orders ---
  // Order 1: Christmas toys
  InsertOrderLine(1, 'LEGO Star Wars Millennium Falcon', 1, 149.99);
  InsertOrderLine(1, 'Rubik''s Cube', 3, 12.99);
  InsertOrderLine(1, 'Nerf Blaster Elite', 2, 29.99);

  // Order 2: Birthday toys
  InsertOrderLine(2, 'Hot Wheels Track Builder', 1, 39.99);
  InsertOrderLine(2, 'Play-Doh Mega Set', 1, 24.99);

  // Order 3: Spring shopping
  InsertOrderLine(3, 'Teddy Bear Deluxe', 1, 34.99);
  InsertOrderLine(3, 'Wooden Train Set', 1, 59.99);
  InsertOrderLine(3, 'Yo-Yo Championship Edition', 4, 8.99);

  // --- Order lines for Scrooge's orders ---
  // Order 4: Bulk purchase (of course)
  InsertOrderLine(4, 'Gold-Plated Chess Set', 10, 199.99);
  InsertOrderLine(4, 'Monopoly Luxury Edition', 50, 49.99);

  // Order 5: Valentine's gift?
  InsertOrderLine(5, 'Teddy Bear Deluxe', 1, 34.99);

  // --- Order lines for Empire ---
  // Order 6: "Training" equipment
  InsertOrderLine(6, 'LEGO Death Star', 100, 499.99);
  InsertOrderLine(6, 'Lightsaber Toy (Red)', 5000, 19.99);
  InsertOrderLine(6, 'Stormtrooper Action Figure', 10000, 14.99);

  // Order 7: More supplies
  InsertOrderLine(7, 'Darth Vader Helmet Replica', 500, 89.99);
  InsertOrderLine(7, 'TIE Fighter Model Kit', 2000, 44.99);

  // --- Order lines for Solo Shipping ---
  // Order 8
  InsertOrderLine(8, 'Sabacc Card Deck', 200, 15.99);
  InsertOrderLine(8, 'Dejarik Board Game', 50, 79.99);
  InsertOrderLine(8, 'Wookiee Plush Toy XL', 100, 39.99);

  // --- Order lines for Huey ---
  // Order 9
  InsertOrderLine(9, 'Junior Woodchucks Compass', 1, 22.99);
  InsertOrderLine(9, 'Camping Tent Playset', 1, 45.99);
end;

end.
