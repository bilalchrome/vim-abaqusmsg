# Abaqus .msg support for Notepad++

This folder gives Notepad++ (version 8 or newer) the main features of the Vim plugin:

| Feature | How it works in Notepad++ |
|---|---|
| Colours: converged = blue, failed check = orange, cutback or divergence = bold underlined vermillion | User Defined Language (UDL) "Abaqus msg" |
| One fold per increment attempt | UDL folding; collapse all with **Alt+0** |
| Overview of every attempt, divergence and error; click to jump | **View → Function List** |
| Jump between cutbacks | **Mark** with a regex and bookmark the lines, then press **F2** |
| List of all problems | **Find All in Current Document** with a regex |
| Follow a running job | **View → Monitoring (tail -f)** |

Mixed CRLF/LF line endings need no fix: Notepad++ shows them correctly.

## Install

1. Close Notepad++.
2. Double-click `install-notepad++.bat`. For a dark theme, run
   `powershell -ExecutionPolicy Bypass -File install-notepad++.ps1 -Dark`.
3. Start Notepad++ and open a `.msg` file. The *Language* menu should show **Abaqus msg**.

The installer does three things:

- copies `AbaqusMsg_light.xml` or `AbaqusMsg_dark.xml` to `%AppData%\Notepad++\userDefineLangs\`
- copies `functionList\abaqusmsg.xml` to `%AppData%\Notepad++\functionList\`
- adds one line to `overrideMap.xml` in that folder (a backup is saved as `overrideMap.xml.bak`)

For a portable Notepad++, add `-ConfigDir <folder that contains config.xml>`. To remove everything, add
`-Uninstall`.

### Manual install

1. Use **Language → User Defined Language → Define your language… → Import…** and choose one of the
   `AbaqusMsg_*.xml` files. Restart Notepad++.
2. Copy `functionList\abaqusmsg.xml` to `%AppData%\Notepad++\functionList\`.
3. In `overrideMap.xml` in that folder, add this line inside `<associationMap>`:

   ```xml
   <association id="abaqusmsg.xml" userDefinedLangName="Abaqus msg" />
   ```

## Usage

**Folding.** Every `INCREMENT n STARTS.` line starts a fold. Use **Alt+0** to collapse all folds; the file then
reads as a list of attempts. Use **Alt+Shift+0** to expand all.

**Function List.** Open it with **View → Function List**. It lists the step, every increment attempt, each
divergence note and each error, in file order. `ATTEMPT NUMBER 2` or higher means that increment was cut back.

**Bookmark the cutbacks (one-time setup).** Open **Search → Mark…** and set it up as follows:

- Find what: `ATTEMPT NUMBER +([2-9]|\d{2,})`
- Search mode: **Regular expression**
- Tick **Bookmark line**
- Click **Mark All**

Now **F2** and **Shift+F2** jump between cutbacks. The dialog remembers the expression for next time.

**List all problems.** Open **Search → Find… → Find All in Current Document** with **Regular expression** and:

```
\*\*\*ERROR|\*\*\*WARNING|DIVERGING|TOO MANY|NOT ACHIEVED|ATTEMPT NUMBER +([2-9]|\d{2,})
```

The results panel lists every match; double-click a line to jump to it.

**Running jobs.** Choose **View → Monitoring (tail -f)**. The file reloads as Abaqus writes and stays at the end.

## Differences from the Vim plugin

- Only the first line of a multi-line ***WARNING / ***ERROR / ***NOTE message is coloured.
- Fold lines show the INCREMENT line itself, not a ✓/✗ summary.
- Retried attempts are found with the Mark search above, not by colour.
- Folding expects one step. In multi-step files, later steps fold inside the last attempt of the previous step.

To change colours or keywords, edit `make_udl.py` and run `python make_udl.py`, or use
**Language → User Defined Language → Define your language…** inside Notepad++.
