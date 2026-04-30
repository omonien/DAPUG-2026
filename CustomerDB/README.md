# CustomerDB — DAPUG 2026 Workshop Demo

A Delphi VCL demo application demonstrating **layered architecture** with SQLite persistence, built entirely using **GitHub Copilot CLI** with a custom Delphi build machine.

## Purpose

This project was created live during the DAPUG 2026 workshop to show how AI-assisted development works with Delphi — including project setup, architecture decisions, debugging, and iterative development.

## Architecture

```
┌─────────────────────────────────┐
│           UI Layer              │  (MainForm, CustomerEditForm)
├─────────────────────────────────┤
│         Service Layer           │  (TCustomerService — facade)
├─────────────────────────────────┤
│       Repository Layer          │  (Interfaces + SQLite impl)
├─────────────────────────────────┤
│         Data Layer              │  (TDatabaseManager, SeedData)
└─────────────────────────────────┘
```

- **Model**: `TCustomer`, `TOrder`, `TOrderLine`
- **Repository**: `ICustomerRepository`, `IOrderRepository` with SQLite implementations
- **Service**: `TCustomerService` as a business logic facade
- **UI**: Customer list with search, detail view, orders/order lines, and full CRUD editor

## Features

- Customer list with real-time search filtering
- Detail panel showing customer info, orders, and order lines
- Full CRUD: Create (Ins), Edit (DblClick), Delete (Del) with cascade
- Auto-creating SQLite database with seed data (14 customers, 9 orders, 20+ lines)
- Themed test data (Star Wars, Duck Universe, classic toys)

## Development Setup

### Tools Used

| Tool | Purpose |
|------|---------|
| **GitHub Copilot CLI** | AI-assisted development in terminal |
| **Delphi 13.1** (Embarcadero RAD Studio) | Compiler and IDE |
| **Custom MCP Build Server** | Remote Delphi compilation from CLI |
| **Delphi Standards MCP** | Coding standards and patterns |
| **SQLite** (via FireDAC) | Local database |

### Build Requirements

- Delphi 13.1 or later (Win32, VCL)
- FireDAC (included with Delphi)
- No external dependencies

### Building

Open `CustomerDB.dproj` in the IDE and build, or use MSBuild:

```powershell
$env:BDS = "C:\Program Files (x86)\Embarcadero\Studio\24.0"  # Adjust path
& "$env:BDS\bin\rsvars.bat"
msbuild CustomerDB.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

### Running

On first run, the application creates `CustomerDB.db` in the executable's directory with seed data.

## Copilot CLI + Delphi Build Machine

This project demonstrates a **custom AI development workflow**:

1. **Copilot CLI** runs in a terminal (no IDE required for code generation)
2. **MCP Servers** provide domain knowledge:
   - `delphi-standards-mcp` — coding standards, patterns, templates
   - `delphi-build-mcp` — remote compilation on a dedicated build machine
   - `easypos-mcp` — business domain knowledge (for production projects)
3. **Workflow Gate** enforces quality:
   - Discovery phase with complexity scoring
   - Standards consultation before implementation
   - Iterative debugging with documented learnings

### Lessons Learned (SQLite + FireDAC)

During development, several FireDAC/SQLite gotchas were discovered and documented:

1. **`FireDAC.VCLUI.Wait`** must be in DPR uses clause — compiles without it but crashes at runtime
2. **No BOOLEAN type** in SQLite — use `AsInteger <> 0`, never `AsBoolean`
3. **DATE/DATETIME stored as TEXT** — `DateTimeFormat=String` connection param does NOT work; must parse ISO strings manually
4. **`CREATE TABLE IF NOT EXISTS`** should always run for robustness

All findings were fed back into the standards MCP for future projects.

## Project Structure

```
CustomerDB/
├── CustomerDB.dpr              # Main program
├── CustomerDB.dproj            # Project file (Delphi 13.1)
├── CustomerDB.Test.dpr         # Console test program
├── CustomerDB.Test.dproj       # Test project file
├── README.md                   # This file
└── Source/
    ├── Model/
    │   ├── CustomerDB.Model.Customer.pas
    │   └── CustomerDB.Model.Order.pas
    ├── Repository/
    │   ├── CustomerDB.Repository.Interfaces.pas
    │   └── CustomerDB.Repository.SQLite.pas
    ├── Service/
    │   └── CustomerDB.Service.CustomerService.pas
    ├── Data/
    │   ├── CustomerDB.Data.Database.pas
    │   └── CustomerDB.Data.SeedData.pas
    └── UI/
        ├── CustomerDB.UI.MainForm.pas / .dfm
        └── CustomerDB.UI.CustomerEditForm.pas / .dfm
```

## License

MIT — See repository root LICENSE file.
