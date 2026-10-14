program CustomerDB;

uses
  Vcl.Forms,
  FireDAC.VCLUI.Wait,
  FireDAC.Phys.SQLite,
  CustomerDB.UI.MainForm in 'Source\UI\CustomerDB.UI.MainForm.pas' {MainForm},
  CustomerDB.Model.Customer in 'Source\Model\CustomerDB.Model.Customer.pas',
  CustomerDB.Model.Order in 'Source\Model\CustomerDB.Model.Order.pas',
  CustomerDB.Repository.Interfaces in 'Source\Repository\CustomerDB.Repository.Interfaces.pas',
  CustomerDB.Repository.SQLite in 'Source\Repository\CustomerDB.Repository.SQLite.pas',
  CustomerDB.Service.CustomerService in 'Source\Service\CustomerDB.Service.CustomerService.pas',
  CustomerDB.Data.Database in 'Source\Data\CustomerDB.Data.Database.pas',
  CustomerDB.Data.SeedData in 'Source\Data\CustomerDB.Data.SeedData.pas',
  CustomerDB.UI.CustomerEditForm in 'Source\UI\CustomerDB.UI.CustomerEditForm.pas' {CustomerEditForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
