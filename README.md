# SE_Powershell
Useful Powershell scripts for Space Engineers 

## Convert-EconomyShipsales

Converts the prefabs of the ships that are available for sale at NPC stations into
player-buildable blueprints. Run the script, select one or more ships, then select
a colour. Your blueprints will be placed into a sub-folder of your blueprints, with
a folder name beginning "Economy - " then the colour you chose.

Thumbnails will be copied from the store block's images, and won't be adjusted to
match your chosen colour.

**Command-line options**
<dl>
<dt><tt>-BlueprintFolder &lt;string&gt;</tt></dt>
<dd>Folder in which to save blueprints. Defaults to "Economy - " followed by the name of the chosen color.</dd>
<dt><tt>-Color &lt;string&gt;</tt></dt>
<dd>A colour, taken from a pre-defined list. If not specified, the user will be asked to choose one.</dd>
<dt><tt>-Ship &lt;String[]&gt;</tt></dt>
<dd>Specify the name or names (separated by commas) of a ship prefab. It's up to you to spell it correctly; the default is to ask the user to select. In the selection screen, the left-most column is what you'd need to provide here.</dd>
<dt><tt>-Legacy</tt></dt>
<dd>Switches the script into legacy mode, for connoisseurs of classic or vintage vehicles (pre-Economy 2 ships).</dd>
<dl>


## Deploy-ToolbarLookup

Creates HTML files describing all fo the toolbars and block references in selected
blueprints. Run the script, then select one or more blueprints. HTML files will be
created in your home folder, and launched in your browser.

Matcha.css will be downloaded from https://matcha.mizu.sh/
