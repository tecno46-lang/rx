require "import"
import "android.app.*"
import "android.content.*"
import "android.net.Uri"
import "android.widget.*"
import "android.view.*"
import "android.graphics.Typeface"
import "com.androlua.LuaDialog"
import "com.androlua.Http"
import "android.os.Handler"
import "android.os.Looper"
import "android.widget.Toast"
import "android.os.Environment"
import "android.net.ConnectivityManager"

-- Java Files handling imports 
import "java.io.File"
import "java.io.FileInputStream"
import "java.io.FileOutputStream"
import "java.util.zip.ZipInputStream"
import "java.lang.reflect.Array"
import "java.lang.Byte"
import "java.lang.Runnable"
import "java.lang.Thread"
import "java.util.Arrays"
import "java.text.SimpleDateFormat"
import "java.util.Date"
import "java.util.Locale"

-- کریش روکنے کے لیے محفوظ کانٹیکسٹ
local ctx = activity or service

local app_title = "Jieshuo Setting Manager by Tech for V I Personal Use"
local developer_info = "Developed by Muhammad Hanzla"

local main_dialog = nil
local SERVER_URL_ABOUT = "https://about-and-support.vercel.app/main.lua"

local cached_about_content = nil
local is_about_loading = false
local about_load_complete = false

local sdcard_path = Environment.getExternalStorageDirectory().getAbsolutePath()
local JIESHUO_PATH = sdcard_path .. "/解说/"
local DOWNLOAD_FOLDER = sdcard_path .. "/Download/"
-- گٹ ہب کا ڈائریکٹ ڈاؤن لوڈ لنک (Raw URL) تاکہ فائل صحیح سے ڈاؤن لوڈ ہو
local JIESHUO_ZIP_URL = "https://raw.githubusercontent.com/tecno46-lang/ss/main/%E8%A7%A3%E8%AF%B4.zip"

local showMainInterface
local showNewSettingWarningDialog
local startNewSettingDownload
local runAutomation
local showResultDialog
local showLoadingDialog

-- ================== ہوم سکرین پر جانے کا فنکشن ==================
local function goHome()
    local intent = Intent(Intent.ACTION_MAIN)
    intent.addCategory(Intent.CATEGORY_HOME)
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    pcall(function() ctx.startActivity(intent) end)
end

-- ================== نیٹ ورک چیک کرنے کا فنکشن ==================
local function isNetworkAvailable()
  local cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
  local netInfo = cm.getActiveNetworkInfo()
  return netInfo ~= nil and netInfo.isConnected()
end

-- ================== فولڈر ڈیلیٹ کرنے کا محفوظ طریقہ ==================
local function deleteDirectory(path)
  local file = File(path)
  if file.exists() then
    if file.isDirectory() then
      local files = file.listFiles()
      if files ~= nil then
        local list = Arrays.asList(files)
        for i = 0, list.size() - 1 do
          deleteDirectory(list.get(i).getAbsolutePath())
        end
      end
    end
    file.delete()
  end
end

-- ================== مکمل سیٹنگ نکالنے کا طریقہ (جاوا Unzip) ==================
local function unzipFile(zipFilePath, destDir)
  local dir = File(destDir)
  if not dir.exists() then dir.mkdirs() end
  
  local zis = ZipInputStream(FileInputStream(zipFilePath))
  local entry = zis.getNextEntry()
  local buffer = Array.newInstance(Byte.TYPE, 8192) 
  
  while entry ~= nil do
      local fileName = entry.getName()
      local newFile = File(destDir, fileName)
      
      if entry.isDirectory() then
          newFile.mkdirs()
      else
          local parent = newFile.getParentFile()
          if not parent.exists() then
              parent.mkdirs()
          end
          
          local fos = FileOutputStream(newFile)
          local len = zis.read(buffer)
          while len > 0 do
              fos.write(buffer, 0, len)
              len = zis.read(buffer)
          end
          fos.close()
      end
      zis.closeEntry()
      entry = zis.getNextEntry()
  end
  zis.close()
end

-- ================== آٹومیشن (ریسٹور) ==================
runAutomation = function()
  Handler(Looper.getMainLooper()).postDelayed(Runnable{
    run = function()
      service.click({
        {"%Advanced settings>10",
        "Backup and restore>10",
        "Local restore>10",
        "OK>10",
        }
      })
      Handler(Looper.getMainLooper()).postDelayed(Runnable{
        run = function()
          service.click({
            {"OK>10"}
          })
        end
      }, 5000)
    end
  }, 2500)
end

-- ================== پروفیشنل ڈائیلاگ: لوڈنگ (Crash Free) ==================
showLoadingDialog = function(title, message)
  local dlg = LuaDialog(ctx)
  local layout = {
    ScrollView, fillViewport = true, layout_width = "fill", layout_height = "fill",
    {
      LinearLayout, orientation = "vertical", padding = "25dp", layout_width = "fill", gravity="center",
      { TextView, text = title, textSize = "18sp", textColor = "#2196F3", gravity = "center", layout_marginBottom = "15dp", typeface = Typeface.DEFAULT_BOLD },
      { TextView, text = message, textSize = "15sp", textColor = "#212121", gravity = "center" }
    }
  }
  dlg.setView(loadlayout(layout))
  dlg.setCancelable(false)
  
  local ok = pcall(function() dlg.show() end)
  if not ok then
      pcall(function() service.speak(title .. ": " .. message) end)
  end
  return dlg
end

-- ================== پروفیشنل ڈائیلاگ: رزلٹ (Crash Free) ==================
showResultDialog = function(title, message, onOkClick)
  local dlg = LuaDialog(ctx)
  local layout = {
    ScrollView, fillViewport = true, layout_width = "fill", layout_height = "fill",
    {
      LinearLayout, orientation = "vertical", padding = "25dp", layout_width = "fill",
      { TextView, text = title, textSize = "18sp", textColor = "#2196F3", gravity = "center", layout_marginBottom = "15dp", typeface = Typeface.DEFAULT_BOLD },
      { TextView, text = message, textSize = "16sp", textColor = "#212121", gravity = "center", layout_marginBottom = "20dp" },
      { Button, text = "OK", layout_width = "fill", backgroundColor = "#4CAF50", textColor = "#FFFFFF", onClick = function() 
          pcall(function() dlg.dismiss() end)
          if onOkClick then onOkClick() end
      end }
    }
  }
  dlg.setView(loadlayout(layout))
  dlg.setCancelable(false)
  
  local ok = pcall(function() dlg.show() end)
  if not ok then
      pcall(function() service.speak(title .. ". " .. message) end)
      pcall(function() Toast.makeText(ctx, title .. ": " .. message, Toast.LENGTH_LONG).show() end)
      if onOkClick then onOkClick() end
  end
end

-- ================== About & Support ==================
local function showErrorDialog(title, message)
  local err_dlg = LuaDialog(ctx)
  local layout = {
    ScrollView, fillViewport = true, layout_width = "fill", layout_height = "fill",
    {
      LinearLayout,
      orientation = "vertical",
      layout_width = "fill",
      layout_height = "wrap",
      padding = "20dp",
      { TextView, text = title, textSize = "18sp", textColor = 0xFF000000, gravity = "center", layout_marginBottom = "10dp", typeface = Typeface.DEFAULT_BOLD },
      { TextView, text = message, textSize = "14sp", textColor = 0xFF000000, layout_marginBottom = "15dp" },
      { Button, text = "OK", layout_width = "fill", layout_height = "wrap", onClick = function() pcall(function() err_dlg.dismiss() end) end }
    }
  }
  err_dlg.setView(loadlayout(layout))
  pcall(function() err_dlg.show() end)
end

local function executeAboutContent(content)
  local str_content = tostring(content)
  
  _G.mainDialog = main_dialog
  _G.main_dialog = main_dialog
  _G.ctx = ctx
  _G.activity = ctx
  _G.service = service
  
  local chunk, err = load(str_content, "=server_main.lua", "t", _ENV or _G)
  if not chunk and loadstring then
    chunk, err = loadstring(str_content)
  end
  
  if chunk then
    local success, err2 = pcall(chunk)
    if not success then showErrorDialog("Runtime Error", tostring(err2)) end
  else
    showErrorDialog("Syntax Error", tostring(err))
  end
end

local function loadAboutInBackground()
  if is_about_loading or about_load_complete then return end
  is_about_loading = true
  Thread(Runnable{
    run = function()
      Http.get(SERVER_URL_ABOUT, function(code, response)
        is_about_loading = false
        if code == 200 and response then
          local strResponse = tostring(response)
          if strResponse:match("%S") then
            cached_about_content = strResponse
            about_load_complete = true
          end
        end
      end)
    end
  }).start()
end

local function loadAboutFromServer(serverUrl)
  if not isNetworkAvailable() then
    pcall(function() Toast.makeText(ctx, "No internet connection!", Toast.LENGTH_SHORT).show() end)
    return
  end
  if cached_about_content and about_load_complete then
    pcall(function() Toast.makeText(ctx, "Loading...", Toast.LENGTH_SHORT).show() end)
    Handler(Looper.getMainLooper()).postDelayed(Runnable{
      run = function()
        executeAboutContent(cached_about_content)
      end
    }, 300)
    return
  end
  pcall(function() Toast.makeText(ctx, "Loading...", Toast.LENGTH_SHORT).show() end)
  Http.get(serverUrl, function(code, response)
    if code == 200 and response then
      local strResponse = tostring(response)
      if strResponse:match("%S") then
        cached_about_content = strResponse
        about_load_complete = true
        executeAboutContent(strResponse)
      else
        pcall(function() Toast.makeText(ctx, "Server returned empty content.", Toast.LENGTH_LONG).show() end)
      end
    else
      local errorMsg = code == 0 and "Network Error" or "HTTP Error: " .. tostring(code)
      pcall(function() Toast.makeText(ctx, "Failed to load: " .. errorMsg, Toast.LENGTH_LONG).show() end)
    end
  end)
end

-- ================== ڈاؤن لوڈ کے دوران دکھنے والا ڈائیلاگ ==================
local function createDownloadingDialog()
  local dlg = LuaDialog(ctx)
  local layout = {
    ScrollView, fillViewport = true, layout_width = "fill", layout_height = "fill",
    {
      LinearLayout,
      orientation = "vertical",
      layout_width = "fill",
      layout_height = "wrap",
      padding = "25dp",
      gravity = "center",
      { TextView, text = app_title, textSize = "16sp", textColor = 0xFF000000, gravity = "center", layout_marginBottom = "15dp", typeface = Typeface.DEFAULT_BOLD },
      { TextView, text = "Downloading settings...\n\nPlease do not close the application or press back. You may press the Home button to let this run in the background.", textSize = "16sp", textColor = 0xFF000000, gravity = "center" }
    }
  }
  dlg.setView(loadlayout(layout))
  dlg.setCancelable(false)
  return dlg
end

-- ================== دوبارہ کوشش کے ساتھ ڈاؤن لوڈ ==================
local function downloadWithRetry(url, path, maxRetries, callback)
  local attempts = 0
  local function tryDownload()
    attempts = attempts + 1
    Http.download(url, path, function(code, path)
      if code == 200 then
        callback(200, path)
      elseif attempts < maxRetries then
        Thread(Runnable{
          run = function()
            Thread.sleep(2000)
            tryDownload()
          end
        }).start()
      else
        callback(code, path)
      end
    end)
  end
  tryDownload()
end

-- ================== نیا ڈاؤن لوڈ ==================
startNewSettingDownload = function()
  if not isNetworkAvailable() then
    pcall(function() Toast.makeText(ctx, "No internet connection! Please connect and try again.", Toast.LENGTH_LONG).show() end)
    showMainInterface()
    return
  end

  local dlg = createDownloadingDialog()
  pcall(function() dlg.show() end)
  
  local tempZipPath = DOWNLOAD_FOLDER .. "jieshuo.zip"
  File(DOWNLOAD_FOLDER).mkdirs()
  
  downloadWithRetry(JIESHUO_ZIP_URL, tempZipPath, 3, function(code, path)
    if code == 200 then
      Thread(Runnable{
        run = function()
          local status, err = pcall(function()
            deleteDirectory(JIESHUO_PATH)
            File(JIESHUO_PATH).mkdirs()
            unzipFile(tempZipPath, JIESHUO_PATH)
            File(tempZipPath).delete() 
          end)
          
          Handler(Looper.getMainLooper()).post(Runnable{
            run = function()
              pcall(function() dlg.dismiss() end)
              if status then
                runAutomation()
              else
                showResultDialog("Extraction Failed", tostring(err))
              end
            end
          })
        end
      }).start()
    else
      Handler(Looper.getMainLooper()).post(Runnable{
        run = function()
          pcall(function() dlg.dismiss() end)
          local msg = code == 0 and "Network Error" or "HTTP Error: " .. code
          showResultDialog("Download Failed", "Failed to download settings: " .. msg)
        end
      })
    end
  end)
end

-- ================== انتباہی ڈائیلاگ ==================
showNewSettingWarningDialog = function()
  local warn_dlg = LuaDialog(ctx)
  local layout = {
    ScrollView, fillViewport = true, layout_width = "fill", layout_height = "fill",
    {
      LinearLayout,
      orientation = "vertical",
      layout_width = "fill",
      layout_height = "wrap",
      padding = "20dp",
      { TextView, text = "Are you sure you want to download new settings? Your previous settings will be permanently deleted.", layout_width = "fill", layout_height = "wrap", textSize = "16sp", textColor = 0xFF000000 },
      { LinearLayout, layout_width = "fill", layout_height = "wrap", orientation = "horizontal", layout_marginTop = "15dp",
        { Button, text = "YES", layout_width = "0dp", layout_weight = "1", onClick = function() pcall(function() warn_dlg.dismiss() end); startNewSettingDownload() end },
        { Button, text = "NO", layout_width = "0dp", layout_weight = "1", onClick = function() pcall(function() warn_dlg.dismiss() end); showMainInterface() end }
      }
    }
  }
  warn_dlg.setView(loadlayout(layout))
  pcall(function() warn_dlg.show() end)
end

-- ================== مین انٹرفیس ==================
showMainInterface = function()
  local main_dlg = LuaDialog(ctx)
  main_dialog = main_dlg
  
  _G.main_dialog = main_dlg
  _G.mainDialog = main_dlg

  local main_layout = {
    ScrollView, fillViewport = true, layout_width = "fill", layout_height = "fill",
    {
      LinearLayout,
      orientation = "vertical",
      layout_width = "fill",
      layout_height = "wrap",
      gravity = "center",
      padding = "16dp",
      { TextView, text = app_title, layout_width = "wrap", layout_height = "wrap", textSize = "18sp", textColor = 0xFF000000, layout_marginBottom = "4dp", gravity = "center", typeface = Typeface.DEFAULT_BOLD },
      { TextView, text = developer_info, layout_width = "wrap", layout_height = "wrap", textSize = "14sp", textColor = 0xAA000000, layout_marginBottom = "25dp", gravity = "center" },
      { Button, text = "DOWNLOAD NEW SETTING", layout_width = "fill", layout_height = "wrap", textSize = "18sp", layout_marginBottom = "10dp",
        onClick = function()
          pcall(function() main_dlg.dismiss() end)
          showNewSettingWarningDialog()
        end
      },
      { Button, text = "ABOUT & SUPPORT", layout_width = "fill", layout_height = "wrap", textSize = "16sp", backgroundColor = "#9C27B0", textColor = "#FFFFFF", layout_marginBottom = "10dp",
        onClick = function() loadAboutFromServer(SERVER_URL_ABOUT) end
      },
      { Button, text = "EXIT", layout_width = "fill", layout_height = "wrap", textSize = "16sp", backgroundColor = "#F44336", textColor = "#FFFFFF",
        onClick = function() 
            pcall(function() main_dlg.dismiss() end)
            main_dialog = nil
            _G.main_dialog = nil
            _G.mainDialog = nil
            goHome()
        end 
      }
    }
  }
  main_dlg.setView(loadlayout(main_layout))
  pcall(function() main_dlg.show() end)

  loadAboutInBackground()
end

-- ================== اسٹارٹ ==================
showMainInterface()