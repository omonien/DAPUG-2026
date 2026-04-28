Please plan the development of the following tool:
DX.DateChanger

The tool shall be developed with Delphi FireMonkey for Windows and macOS.
It shall have a minimalistic GUI that consists only of a drop zone containing a short explanation of what the function does.

Files dropped onto this drop zone shall be examined to check whether they conform to the following filename schema:
YYYY-MM-DDxyz
A file shall only be processed if it begins with YYYY-MM-DD. The text after the date (xyz) is irrelevant.

If a matching file is found, its creation date and modification date shall be set to exactly that date at 10:00 in the morning, local time zone. Otherwise no change at all.

Create a detailed PRD.
