unit CustomerDB.UI.MainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  CustomerDB.Model.Customer,
  CustomerDB.Model.Order,
  CustomerDB.Service.CustomerService,
  CustomerDB.Data.Database,
  CustomerDB.Repository.Interfaces,
  CustomerDB.Repository.SQLite;

type
  TMainForm = class(TForm)
    SplitterMain: TSplitter;
    PanelLeft: TPanel;
    PanelSearch: TPanel;
    EditSearch: TEdit;
    ListViewCustomers: TListView;
    PanelRight: TPanel;
    SplitterRight: TSplitter;
    PanelCustomerDetail: TPanel;
    GroupBoxCustomer: TGroupBox;
    LabelName: TLabel;
    LabelNameValue: TLabel;
    LabelCompany: TLabel;
    LabelCompanyValue: TLabel;
    LabelEmail: TLabel;
    LabelEmailValue: TLabel;
    LabelPhone: TLabel;
    LabelPhoneValue: TLabel;
    LabelCity: TLabel;
    LabelCityValue: TLabel;
    LabelCVR: TLabel;
    LabelCVRValue: TLabel;
    LabelCountry: TLabel;
    LabelCountryValue: TLabel;
    PanelOrders: TPanel;
    SplitterOrders: TSplitter;
    ListViewOrders: TListView;
    ListViewOrderLines: TListView;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure EditSearchChange(Sender: TObject);
    procedure ListViewCustomersSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure ListViewOrdersSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure ListViewCustomersDblClick(Sender: TObject);
    procedure ListViewCustomersKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    FDatabaseManager: TDatabaseManager;
    FService: TCustomerService;
    FCustomers: TObjectList<TCustomer>;
    FOrders: TObjectList<TOrder>;
    FOrderLines: TObjectList<TOrderLine>;
    procedure LoadCustomers(const aFilter: string = '');
    procedure ShowCustomerDetails(aCustomer: TCustomer);
    procedure LoadOrders(aCustomerId: Integer);
    procedure LoadOrderLines(aOrderId: Integer);
    procedure ClearDetails;
    procedure ClearOrders;
    procedure ClearOrderLines;
    procedure DoEditCustomer;
    procedure DoNewCustomer;
    procedure DoDeleteCustomer;
  end;

var
  MainForm: TMainForm;

implementation

uses
  System.UITypes,
  CustomerDB.UI.CustomerEditForm;

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
var
  lCustomerRepo: ICustomerRepository;
  lOrderRepo: IOrderRepository;
begin
  FDatabaseManager := TDatabaseManager.Create;
  FDatabaseManager.Initialize;

  lCustomerRepo := TSQLiteCustomerRepository.Create(FDatabaseManager.Connection);
  lOrderRepo := TSQLiteOrderRepository.Create(FDatabaseManager.Connection);
  FService := TCustomerService.Create(lCustomerRepo, lOrderRepo);

  LoadCustomers;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FOrderLines.Free;
  FOrders.Free;
  FCustomers.Free;
  FService.Free;
  FDatabaseManager.Free;
end;

procedure TMainForm.EditSearchChange(Sender: TObject);
begin
  LoadCustomers(EditSearch.Text);
end;

procedure TMainForm.LoadCustomers(const aFilter: string);
var
  lCustomer: TCustomer;
  lItem: TListItem;
begin
  ListViewCustomers.Items.BeginUpdate;
  try
    ListViewCustomers.Items.Clear;
    FreeAndNil(FCustomers);

    if aFilter.IsEmpty then
      FCustomers := FService.GetAllCustomers
    else
      FCustomers := FService.SearchCustomers(aFilter);

    for lCustomer in FCustomers do
    begin
      lItem := ListViewCustomers.Items.Add;
      lItem.Caption := lCustomer.FullName;
      lItem.SubItems.Add(lCustomer.Company);
      lItem.SubItems.Add(lCustomer.City);
      if lCustomer.IsBusinessCustomer then
        lItem.SubItems.Add('B2B')
      else
        lItem.SubItems.Add('B2C');
      lItem.Data := lCustomer;
    end;
  finally
    ListViewCustomers.Items.EndUpdate;
  end;

  ClearDetails;
  ClearOrders;
  ClearOrderLines;
end;

procedure TMainForm.ListViewCustomersSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
var
  lCustomer: TCustomer;
begin
  if Selected and (Item <> nil) and (Item.Data <> nil) then
  begin
    lCustomer := TCustomer(Item.Data);
    ShowCustomerDetails(lCustomer);
    LoadOrders(lCustomer.Id);
  end
  else
  begin
    ClearDetails;
    ClearOrders;
    ClearOrderLines;
  end;
end;

procedure TMainForm.ShowCustomerDetails(aCustomer: TCustomer);
begin
  LabelNameValue.Caption := aCustomer.FullName;
  LabelCompanyValue.Caption := aCustomer.Company;
  LabelEmailValue.Caption := aCustomer.Email;
  LabelPhoneValue.Caption := aCustomer.Phone;
  LabelCityValue.Caption := aCustomer.City;
  LabelCountryValue.Caption := aCustomer.Country;
  LabelCVRValue.Caption := aCustomer.CVR;
end;

procedure TMainForm.LoadOrders(aCustomerId: Integer);
var
  lOrder: TOrder;
  lItem: TListItem;
begin
  ListViewOrders.Items.BeginUpdate;
  try
    ListViewOrders.Items.Clear;
    ClearOrderLines;
    FreeAndNil(FOrders);

    FOrders := FService.GetCustomerOrders(aCustomerId);

    for lOrder in FOrders do
    begin
      lItem := ListViewOrders.Items.Add;
      lItem.Caption := Format('#%d', [lOrder.Id]);
      lItem.SubItems.Add(DateToStr(lOrder.OrderDate));
      lItem.SubItems.Add(lOrder.Status);
      lItem.SubItems.Add(''); // Total calculated when lines loaded
      lItem.Data := lOrder;
    end;
  finally
    ListViewOrders.Items.EndUpdate;
  end;
end;

procedure TMainForm.ListViewOrdersSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
var
  lOrder: TOrder;
begin
  if Selected and (Item <> nil) and (Item.Data <> nil) then
  begin
    lOrder := TOrder(Item.Data);
    LoadOrderLines(lOrder.Id);
  end
  else
    ClearOrderLines;
end;

procedure TMainForm.LoadOrderLines(aOrderId: Integer);
var
  lLine: TOrderLine;
  lItem: TListItem;
  lTotal: Double;
begin
  ListViewOrderLines.Items.BeginUpdate;
  try
    ListViewOrderLines.Items.Clear;
    FreeAndNil(FOrderLines);

    FOrderLines := FService.GetOrderLines(aOrderId);
    lTotal := 0;

    for lLine in FOrderLines do
    begin
      lItem := ListViewOrderLines.Items.Add;
      lItem.Caption := lLine.ProductName;
      lItem.SubItems.Add(IntToStr(lLine.Quantity));
      lItem.SubItems.Add(Format('%.2f', [lLine.UnitPrice]));
      lItem.SubItems.Add(Format('%.2f', [lLine.LineTotal]));
      lTotal := lTotal + lLine.LineTotal;
    end;

    // Update order total in orders list
    if (ListViewOrders.Selected <> nil) then
      ListViewOrders.Selected.SubItems[2] := Format('%.2f', [lTotal]);
  finally
    ListViewOrderLines.Items.EndUpdate;
  end;
end;

procedure TMainForm.ClearDetails;
begin
  LabelNameValue.Caption := '';
  LabelCompanyValue.Caption := '';
  LabelEmailValue.Caption := '';
  LabelPhoneValue.Caption := '';
  LabelCityValue.Caption := '';
  LabelCountryValue.Caption := '';
  LabelCVRValue.Caption := '';
end;

procedure TMainForm.ClearOrders;
begin
  ListViewOrders.Items.Clear;
  FreeAndNil(FOrders);
end;

procedure TMainForm.ClearOrderLines;
begin
  ListViewOrderLines.Items.Clear;
  FreeAndNil(FOrderLines);
end;

procedure TMainForm.ListViewCustomersDblClick(Sender: TObject);
begin
  DoEditCustomer;
end;

procedure TMainForm.ListViewCustomersKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_INSERT: DoNewCustomer;
    VK_DELETE: DoDeleteCustomer;
  end;
end;

procedure TMainForm.DoEditCustomer;
var
  lCustomer: TCustomer;
begin
  if ListViewCustomers.Selected = nil then
    Exit;

  lCustomer := TCustomer(ListViewCustomers.Selected.Data);
  if TCustomerEditForm.EditCustomer(lCustomer) then
  begin
    FService.UpdateCustomer(lCustomer);
    LoadCustomers(EditSearch.Text);
  end;
end;

procedure TMainForm.DoNewCustomer;
var
  lCustomer: TCustomer;
begin
  if TCustomerEditForm.NewCustomer(lCustomer) then
  begin
    FService.CreateCustomer(lCustomer);
    lCustomer.Free;
    LoadCustomers(EditSearch.Text);
  end;
end;

procedure TMainForm.DoDeleteCustomer;
var
  lCustomer: TCustomer;
begin
  if ListViewCustomers.Selected = nil then
    Exit;

  lCustomer := TCustomer(ListViewCustomers.Selected.Data);
  if MessageDlg(Format('Delete customer "%s"?', [lCustomer.DisplayName]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FService.DeleteCustomer(lCustomer.Id);
    LoadCustomers(EditSearch.Text);
  end;
end;

end.
