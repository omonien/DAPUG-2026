object CustomerEditForm: TCustomerEditForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Customer'
  ClientHeight = 380
  ClientWidth = 450
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  object LabelFirstName: TLabel
    Left = 16
    Top = 20
    Width = 62
    Height = 15
    Caption = 'First Name:'
  end
  object LabelLastName: TLabel
    Left = 16
    Top = 52
    Width = 60
    Height = 15
    Caption = 'Last Name:'
  end
  object LabelCompany: TLabel
    Left = 16
    Top = 84
    Width = 56
    Height = 15
    Caption = 'Company:'
  end
  object LabelEmail: TLabel
    Left = 16
    Top = 116
    Width = 34
    Height = 15
    Caption = 'Email:'
  end
  object LabelPhone: TLabel
    Left = 16
    Top = 148
    Width = 39
    Height = 15
    Caption = 'Phone:'
  end
  object LabelAddress: TLabel
    Left = 16
    Top = 180
    Width = 47
    Height = 15
    Caption = 'Address:'
  end
  object LabelCity: TLabel
    Left = 16
    Top = 212
    Width = 24
    Height = 15
    Caption = 'City:'
  end
  object LabelZipCode: TLabel
    Left = 280
    Top = 212
    Width = 50
    Height = 15
    Caption = 'Zip Code:'
  end
  object LabelCountry: TLabel
    Left = 16
    Top = 244
    Width = 48
    Height = 15
    Caption = 'Country:'
  end
  object LabelCVR: TLabel
    Left = 280
    Top = 276
    Width = 25
    Height = 15
    Caption = 'CVR:'
  end
  object EditFirstName: TEdit
    Left = 110
    Top = 17
    Width = 320
    Height = 23
    TabOrder = 0
  end
  object EditLastName: TEdit
    Left = 110
    Top = 49
    Width = 320
    Height = 23
    TabOrder = 1
  end
  object EditCompany: TEdit
    Left = 110
    Top = 81
    Width = 320
    Height = 23
    TabOrder = 2
  end
  object EditEmail: TEdit
    Left = 110
    Top = 113
    Width = 320
    Height = 23
    TabOrder = 3
  end
  object EditPhone: TEdit
    Left = 110
    Top = 145
    Width = 320
    Height = 23
    TabOrder = 4
  end
  object EditAddress: TEdit
    Left = 110
    Top = 177
    Width = 320
    Height = 23
    TabOrder = 5
  end
  object EditCity: TEdit
    Left = 110
    Top = 209
    Width = 155
    Height = 23
    TabOrder = 6
  end
  object EditZipCode: TEdit
    Left = 335
    Top = 209
    Width = 95
    Height = 23
    TabOrder = 7
  end
  object EditCountry: TEdit
    Left = 110
    Top = 241
    Width = 155
    Height = 23
    TabOrder = 8
  end
  object CheckBoxBusiness: TCheckBox
    Left = 16
    Top = 276
    Width = 150
    Height = 17
    Caption = 'Business Customer'
    TabOrder = 9
    OnClick = CheckBoxBusinessClick
  end
  object EditCVR: TEdit
    Left = 335
    Top = 273
    Width = 95
    Height = 23
    TabOrder = 10
  end
  object ButtonOK: TButton
    Left = 260
    Top = 340
    Width = 85
    Height = 28
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 11
  end
  object ButtonCancel: TButton
    Left = 350
    Top = 340
    Width = 85
    Height = 28
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 12
  end
end
