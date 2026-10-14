object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'CustomerDB - Demo'
  ClientHeight = 600
  ClientWidth = 1000
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object SplitterMain: TSplitter
    Left = 350
    Top = 0
    Width = 5
    Height = 600
    ExplicitHeight = 500
  end
  object PanelLeft: TPanel
    Left = 0
    Top = 0
    Width = 350
    Height = 600
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object PanelSearch: TPanel
      Left = 0
      Top = 0
      Width = 350
      Height = 35
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object EditSearch: TEdit
        Left = 4
        Top = 6
        Width = 342
        Height = 23
        TabOrder = 0
        TextHint = 'Search customers...'
        OnChange = EditSearchChange
      end
    end
    object ListViewCustomers: TListView
      Left = 0
      Top = 35
      Width = 350
      Height = 565
      Align = alClient
      Columns = <
        item
          Caption = 'Name'
          Width = 120
        end
        item
          Caption = 'Company'
          Width = 100
        end
        item
          Caption = 'City'
          Width = 70
        end
        item
          Caption = 'Type'
          Width = 50
        end>
      ReadOnly = True
      RowSelect = True
      TabOrder = 1
      ViewStyle = vsReport
      OnDblClick = ListViewCustomersDblClick
      OnKeyDown = ListViewCustomersKeyDown
      OnSelectItem = ListViewCustomersSelectItem
    end
  end
  object PanelRight: TPanel
    Left = 355
    Top = 0
    Width = 645
    Height = 600
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object SplitterRight: TSplitter
      Left = 0
      Top = 200
      Width = 645
      Height = 5
      Cursor = crVSplit
      Align = alTop
      ExplicitWidth = 500
    end
    object PanelCustomerDetail: TPanel
      Left = 0
      Top = 0
      Width = 645
      Height = 200
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object GroupBoxCustomer: TGroupBox
        Left = 8
        Top = 4
        Width = 629
        Height = 190
        Caption = ' Customer Details '
        TabOrder = 0
        object LabelName: TLabel
          Left = 16
          Top = 24
          Width = 35
          Height = 15
          Caption = 'Name:'
        end
        object LabelNameValue: TLabel
          Left = 100
          Top = 24
          Width = 3
          Height = 15
          Font.Style = [fsBold]
          ParentFont = False
        end
        object LabelCompany: TLabel
          Left = 16
          Top = 48
          Width = 56
          Height = 15
          Caption = 'Company:'
        end
        object LabelCompanyValue: TLabel
          Left = 100
          Top = 48
          Width = 3
          Height = 15
        end
        object LabelEmail: TLabel
          Left = 16
          Top = 72
          Width = 34
          Height = 15
          Caption = 'Email:'
        end
        object LabelEmailValue: TLabel
          Left = 100
          Top = 72
          Width = 3
          Height = 15
        end
        object LabelPhone: TLabel
          Left = 16
          Top = 96
          Width = 39
          Height = 15
          Caption = 'Phone:'
        end
        object LabelPhoneValue: TLabel
          Left = 100
          Top = 96
          Width = 3
          Height = 15
        end
        object LabelCity: TLabel
          Left = 16
          Top = 120
          Width = 24
          Height = 15
          Caption = 'City:'
        end
        object LabelCityValue: TLabel
          Left = 100
          Top = 120
          Width = 3
          Height = 15
        end
        object LabelCVR: TLabel
          Left = 16
          Top = 144
          Width = 25
          Height = 15
          Caption = 'CVR:'
        end
        object LabelCVRValue: TLabel
          Left = 100
          Top = 144
          Width = 3
          Height = 15
        end
        object LabelCountry: TLabel
          Left = 16
          Top = 168
          Width = 48
          Height = 15
          Caption = 'Country:'
        end
        object LabelCountryValue: TLabel
          Left = 100
          Top = 168
          Width = 3
          Height = 15
        end
      end
    end
    object PanelOrders: TPanel
      Left = 0
      Top = 205
      Width = 645
      Height = 395
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object SplitterOrders: TSplitter
        Left = 0
        Top = 175
        Width = 645
        Height = 5
        Cursor = crVSplit
        Align = alTop
        ExplicitWidth = 500
      end
      object ListViewOrders: TListView
        Left = 0
        Top = 0
        Width = 645
        Height = 175
        Align = alTop
        Columns = <
          item
            Caption = 'Order #'
            Width = 70
          end
          item
            Caption = 'Date'
            Width = 100
          end
          item
            Caption = 'Status'
            Width = 80
          end
          item
            Caption = 'Total'
            Alignment = taRightJustify
            Width = 100
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnSelectItem = ListViewOrdersSelectItem
      end
      object ListViewOrderLines: TListView
        Left = 0
        Top = 180
        Width = 645
        Height = 215
        Align = alClient
        Columns = <
          item
            Caption = 'Product'
            Width = 250
          end
          item
            Caption = 'Qty'
            Alignment = taRightJustify
            Width = 60
          end
          item
            Caption = 'Unit Price'
            Alignment = taRightJustify
            Width = 90
          end
          item
            Caption = 'Line Total'
            Alignment = taRightJustify
            Width = 100
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
      end
    end
  end
end
