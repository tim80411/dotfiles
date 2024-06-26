# dotFiles
## description
**fork from Alfredo**

adapt self setting

## demo
![alfredo-iTern-demo](./images/alfredo-iTern-demo.png)
## macOS
### 1. `install.sh`
   
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/install.sh)"
   ```
### 2. Setting `iTerm` font family


   open iTerm and press

   ```
   ⌘ + ,
   ```
   ```
   profiles -> Text -> font -> choose `Hack Nerd Font`
   ```
![setting-iTerm-font](./images/setting-iTern-font.png)

### 3. Setting `VSCode` font family

   open **VSCode** and press

   ```
   ⌘ + ,
   ```

   choose `user` & open `settings.json`

   ![vscode-font-setting](./images/vscode_font_setting.png)


   copy into `settings.json`
   ```shell
   "editor.fontFamily": "'Cascadia Code', Consolas, 'Courier New', monospace",
   "editor.fontLigatures": true,
   "terminal.integrated.fontFamily": "'Hack Nerd Font Mono'",
   ```
   ![vscode_settings_json](./images/vscode_settings_json.png)

   ![vscode_font_result](./images/vscode_font_result.png)