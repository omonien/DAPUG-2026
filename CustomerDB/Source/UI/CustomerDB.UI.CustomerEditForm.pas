unit CustomerDB.UI.CustomerEditForm;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  CustomerDB.Model.Customer;

type
  TCustomerEditForm = class(TForm)
    LabelFirstName: TLabel;
    LabelLastName: TLabel;
    LabelCompany: TLabel;
    LabelEmail: TLabel;
    LabelPhone: TLabel;
    LabelAddress: TLabel;
    LabelCity: TLabel;
    LabelZipCode: TLabel;
    LabelCountry: TLabel;
    LabelCVR: TLabel;
    EditFirstName: TEdit;
    EditLastName: TEdit;
    EditCompany: TEdit;
    EditEmail: TEdit;
    EditPhone: TEdit;
    EditAddress: TEdit;
    EditCity: TEdit;
    EditZipCode: TEdit;
    EditCountry: TEdit;
    EditCVR: TEdit;
    CheckBoxBusiness: TCheckBox;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    procedure CheckBoxBusinessClick(Sender: TObject);
  private
    procedure LoadFromCustomer(aCustomer: TCustomer);
    procedure SaveToCustomer(aCustomer: TCustomer);
  public
    class function EditCustomer(aCustomer: TCustomer): Boolean;
    class function NewCustomer(out aCustomer: TCustomer): Boolean;
  end;

implementation

{$R *.dfm}

procedure TCustomerEditForm.CheckBoxBusinessClick(Sender: TObject);
begin
  EditCVR.Enabled := CheckBoxBusiness.Checked;
  if not CheckBoxBusiness.Checked then
    EditCVR.Text := '';
end;

procedure TCustomerEditForm.LoadFromCustomer(aCustomer: TCustomer);
begin
  EditFirstName.Text := aCustomer.FirstName;
  EditLastName.Text := aCustomer.LastName;
  EditCompany.Text := aCustomer.Company;
  EditEmail.Text := aCustomer.Email;
  EditPhone.Text := aCustomer.Phone;
  EditAddress.Text := aCustomer.Address;
  EditCity.Text := aCustomer.City;
  EditZipCode.Text := aCustomer.ZipCode;
  EditCountry.Text := aCustomer.Country;
  EditCVR.Text := aCustomer.CVR;
  CheckBoxBusiness.Checked := aCustomer.IsBusinessCustomer;
  EditCVR.Enabled := aCustomer.IsBusinessCustomer;
end;

procedure TCustomerEditForm.SaveToCustomer(aCustomer: TCustomer);
begin
  aCustomer.FirstName := Trim(EditFirstName.Text);
  aCustomer.LastName := Trim(EditLastName.Text);
  aCustomer.Company := Trim(EditCompany.Text);
  aCustomer.Email := Trim(EditEmail.Text);
  aCustomer.Phone := Trim(EditPhone.Text);
  aCustomer.Address := Trim(EditAddress.Text);
  aCustomer.City := Trim(EditCity.Text);
  aCustomer.ZipCode := Trim(EditZipCode.Text);
  aCustomer.Country := Trim(EditCountry.Text);
  aCustomer.CVR := Trim(EditCVR.Text);
  aCustomer.IsBusinessCustomer := CheckBoxBusiness.Checked;
end;

class function TCustomerEditForm.EditCustomer(aCustomer: TCustomer): Boolean;
var
  lForm: TCustomerEditForm;
begin
  lForm := TCustomerEditForm.Create(Application);
  try
    lForm.Caption := 'Edit Customer - ' + aCustomer.FullName;
    lForm.LoadFromCustomer(aCustomer);
    Result := lForm.ShowModal = mrOk;
    if Result then
      lForm.SaveToCustomer(aCustomer);
  finally
    lForm.Free;
  end;
end;

class function TCustomerEditForm.NewCustomer(out aCustomer: TCustomer): Boolean;
var
  lForm: TCustomerEditForm;
begin
  aCustomer := nil;
  lForm := TCustomerEditForm.Create(Application);
  try
    lForm.Caption := 'New Customer';
    lForm.EditCountry.Text := 'USA';
    Result := lForm.ShowModal = mrOk;
    if Result then
    begin
      aCustomer := TCustomer.Create;
      lForm.SaveToCustomer(aCustomer);
    end;
  finally
    lForm.Free;
  end;
end;

end.
