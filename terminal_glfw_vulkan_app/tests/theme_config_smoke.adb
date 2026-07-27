with AUnit.Assertions;

with Terminal.App.Config;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Theme;
with Terminal.Core;

procedure Theme_Config_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Config.Line_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Theme.Theme_Name;
   use type Terminal.Core.Initialize_Status;

   R : Terminal.App.Renderer.Renderer;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   Render_Status   : Terminal.App.Renderer.Render_Status;
   T : Terminal.Core.Terminal;
   Core_Status : Terminal.Core.Initialize_Status;

   procedure Assert_Close
     (Actual   : Float;
      Expected : Float;
      Message  : String)
   is
   begin
      Assert (abs (Actual - Expected) < 0.001, Message);
   end Assert_Close;

   procedure Assert_Color
     (Actual   : Terminal.App.Render_Model.Pixel_Color;
      Expected : Terminal.App.Render_Model.Pixel_Color;
      Message  : String)
   is
   begin
      Assert_Close (Actual.R, Expected.R, Message & " red");
      Assert_Close (Actual.G, Expected.G, Message & " green");
      Assert_Close (Actual.B, Expected.B, Message & " blue");
      Assert_Close (Actual.A, Expected.A, Message & " alpha");
   end Assert_Color;
begin
   declare
      Name : Terminal.App.Theme.Theme_Name;
   begin
      Assert
        (Terminal.App.Theme.Parse_Name ("dark", Name),
         "dark theme name should parse");
      Assert
        (Name = Terminal.App.Theme.Default_Dark,
         "dark theme should resolve to default dark");
      Assert
        (Terminal.App.Theme.Status_Label (Name) =
         "Theme default-dark active",
         "theme status label");
      Assert
        (Terminal.App.Theme.Status_Label (Name)'Length <=
         Terminal.App.Theme.Max_Status_Label_Length,
         "theme status label should be bounded");
      Assert
        (Terminal.App.Theme.Parse_Name ("high_contrast", Name),
         "high_contrast theme name should parse");
      Assert
        (Name = Terminal.App.Theme.High_Contrast,
         "high_contrast theme should resolve");
      Assert
        (not Terminal.App.Theme.Parse_Name ("missing", Name),
         "unknown theme should be rejected");
   end;

   declare
      C : constant Terminal.App.Config.Config :=
        (Color_Theme      => Terminal.App.Theme.Light,
         Scrollback_Limit => Terminal.App.Config.Default_Scrollback_Limit,
         Wheel_Scroll_Lines =>
           Terminal.App.Config.Default_Wheel_Scroll_Lines,
         Window_Width => Terminal.App.Config.Default_Window_Width,
         Window_Height => Terminal.App.Config.Default_Window_Height,
         Startup_Rows => Terminal.App.Config.Default_Startup_Rows,
         Startup_Cols => Terminal.App.Config.Default_Startup_Cols);
      Light : constant Terminal.App.Theme.Theme :=
        Terminal.App.Config.Active_Theme (C);
   begin
      Assert_Color
        (Light.Default_BG,
         Terminal.App.Theme.Built_In (Terminal.App.Theme.Light).Default_BG,
         "config-selected theme");
   end;

   declare
      C : Terminal.App.Config.Config;
      Accepted : Boolean;
      Status : Terminal.App.Config.Line_Status;
   begin
      Assert
        (C.Scrollback_Limit =
         Terminal.App.Config.Default_Scrollback_Limit,
         "default scrollback limit");
      Assert
        (C.Wheel_Scroll_Lines =
         Terminal.App.Config.Default_Wheel_Scroll_Lines,
         "default wheel scroll lines");
      Assert
        (C.Window_Width = Terminal.App.Config.Default_Window_Width,
         "default window width");
      Assert
        (C.Window_Height = Terminal.App.Config.Default_Window_Height,
         "default window height");
      Assert
        (C.Startup_Rows = Terminal.App.Config.Default_Startup_Rows,
         "default startup rows");
      Assert
        (C.Startup_Cols = Terminal.App.Config.Default_Startup_Cols,
         "default startup cols");
      Terminal.App.Config.Apply_Line (C, "", Status);
      Assert
        (Status = Terminal.App.Config.Ignored_Blank,
         "blank config line status");
      Assert
        (Terminal.App.Config.Line_Status_Label (Status) =
         "Blank config line ignored",
         "blank config line status label");
      Assert
        (Terminal.App.Config.Line_Status_Label (Status)'Length <=
         Terminal.App.Config.Max_Status_Label_Length,
         "config line status label should be bounded");
      Terminal.App.Config.Apply_Line (C, "# comment", Status);
      Assert
        (Status = Terminal.App.Config.Ignored_Comment,
         "comment config line status");
      Assert
        (Terminal.App.Config.Line_Status_Label (Status) =
         "Comment config line ignored",
         "comment config line status label");
      Terminal.App.Config.Apply_Line (C, "theme = missing", Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "invalid theme value status");
      Assert
        (Terminal.App.Config.Line_Status_Label (Status) =
         "Invalid config value",
         "invalid config value status label");
      Terminal.App.Config.Apply_Line (C, "theme light", Status);
      Assert
        (Status = Terminal.App.Config.Missing_Separator,
         "missing separator status");
      Assert
        (Terminal.App.Config.Line_Status_Label (Status) =
         "Config line missing separator",
         "missing separator status label");
      Terminal.App.Config.Apply_Line (C, "unknown = light", Status);
      Assert
        (Status = Terminal.App.Config.Unknown_Key,
         "unknown config key status");
      Assert
        (Terminal.App.Config.Line_Status_Label (Status) =
         "Unknown config key",
         "unknown config key status label");
      Terminal.App.Config.Apply_Line (C, "scrollback-limit = 250", Status);
      Assert
        (Status = Terminal.App.Config.Accepted,
         "scrollback limit status");
      Assert
        (Terminal.App.Config.Line_Status_Label (Status) =
         "Config line accepted",
         "accepted config line status label");
      Assert (C.Scrollback_Limit = 250, "scrollback limit value");
      Terminal.App.Config.Apply_Line (C, "scrollback-rows = 0", Status);
      Assert
        (Status = Terminal.App.Config.Accepted,
         "zero scrollback rows status");
      Assert (C.Scrollback_Limit = 0, "zero scrollback rows value");
      Terminal.App.Config.Apply_Line (C, "scrollback-limit = abc", Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "invalid scrollback limit status");
      Assert
        (C.Scrollback_Limit = 0,
         "invalid scrollback limit should preserve value");
      Terminal.App.Config.Apply_Line
        (C,
         "scrollback-limit ="
         & Natural'Image (Terminal.App.Config.Max_Scrollback_Limit + 1),
         Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "oversized scrollback limit status");
      Assert
        (C.Scrollback_Limit = 0,
         "oversized scrollback limit should preserve value");
      Terminal.App.Config.Apply_Line (C, "wheel-scroll-lines = 7", Status);
      Assert
        (Status = Terminal.App.Config.Accepted,
         "wheel scroll lines status");
      Assert (C.Wheel_Scroll_Lines = 7, "wheel scroll lines value");
      Terminal.App.Config.Apply_Line (C, "scroll-lines = 1", Status);
      Assert
        (Status = Terminal.App.Config.Accepted,
         "scroll-lines alias status");
      Assert (C.Wheel_Scroll_Lines = 1, "scroll-lines alias value");
      Terminal.App.Config.Apply_Line (C, "wheel-scroll-lines = 0", Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "zero wheel scroll lines status");
      Assert
        (C.Wheel_Scroll_Lines = 1,
         "zero wheel scroll lines should preserve value");
      Terminal.App.Config.Apply_Line
        (C,
         "wheel-scroll-lines ="
         & Natural'Image (Terminal.App.Config.Max_Wheel_Scroll_Lines + 1),
         Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "oversized wheel scroll lines status");
      Assert
        (C.Wheel_Scroll_Lines = 1,
         "oversized wheel scroll lines should preserve value");
      Terminal.App.Config.Apply_Line (C, "window-width = 1200", Status);
      Assert
        (Status = Terminal.App.Config.Accepted,
         "window width status");
      Assert (C.Window_Width = 1200, "window width value");
      Terminal.App.Config.Apply_Line (C, "window-height = 720", Status);
      Assert
        (Status = Terminal.App.Config.Accepted,
         "window height status");
      Assert (C.Window_Height = 720, "window height value");
      Terminal.App.Config.Apply_Line (C, "startup-rows = 40", Status);
      Assert
        (Status = Terminal.App.Config.Accepted,
         "startup rows status");
      Assert (C.Startup_Rows = 40, "startup rows value");
      Terminal.App.Config.Apply_Line (C, "startup-cols = 120", Status);
      Assert
        (Status = Terminal.App.Config.Accepted,
         "startup cols status");
      Assert (C.Startup_Cols = 120, "startup cols value");
      Terminal.App.Config.Apply_Line (C, "window-width = 0", Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "zero window width status");
      Assert (C.Window_Width = 1200, "zero window width preserves value");
      Terminal.App.Config.Apply_Line
        (C,
         "window-height ="
         & Natural'Image (Terminal.App.Config.Max_Window_Dimension + 1),
         Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "oversized window height status");
      Assert (C.Window_Height = 720, "oversized window height preserves value");
      Terminal.App.Config.Apply_Line (C, "startup-rows = 0", Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "zero startup rows status");
      Assert (C.Startup_Rows = 40, "zero startup rows preserves value");
      Terminal.App.Config.Apply_Line
        (C,
         "startup-cols ="
         & Natural'Image (Terminal.App.Config.Max_Startup_Cells + 1),
         Status);
      Assert
        (Status = Terminal.App.Config.Invalid_Value,
         "oversized startup cols status");
      Assert (C.Startup_Cols = 120, "oversized startup cols preserves value");

      Terminal.App.Config.Apply_Line (C, "# comment", Accepted);
      Assert (Accepted, "comment config line should be accepted");
      Terminal.App.Config.Apply_Line (C, "theme = high-contrast", Accepted);
      Assert (Accepted, "theme config line should be accepted");
      Assert
        (C.Color_Theme = Terminal.App.Theme.High_Contrast,
         "theme config line should update theme");
      Terminal.App.Config.Apply_Line (C, "unknown = light", Accepted);
      Assert (not Accepted, "unknown config key should be rejected");
      Assert
        (Terminal.App.Config.Image (C) =
         "theme=high-contrast"
         & " scrollback-limit=0"
         & " wheel-scroll-lines=1"
         & " window=1200x720"
         & " startup-grid=40x120",
         "config image should expose effective settings");
      Assert
        (Terminal.App.Config.Status_Label (C) =
         "Theme high-contrast active; window 1200x720; startup grid 40x120",
         "config status label");
      Assert
        (Terminal.App.Config.Status_Label (C)'Length <=
         Terminal.App.Config.Max_Status_Label_Length,
         "config status label should be bounded");
   end;

   Terminal.App.Renderer.Initialize_Headless (R, Renderer_Status);
   Assert
     (Renderer_Status = Terminal.App.Renderer.Ok,
      "renderer initialize failed");
   Terminal.App.Renderer.Set_Theme
     (R, Terminal.App.Theme.Built_In (Terminal.App.Theme.Light));

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core initialize failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
      Light : constant Terminal.App.Theme.Theme :=
        Terminal.App.Theme.Built_In (Terminal.App.Theme.Light);
   begin
      Assert (Frame.Rectangle_Count >= 3, "theme render rectangles");
      Assert_Color
        (Frame.Rectangles (1).Color,
         Light.Default_BG,
         "frame background should use selected theme");
      Assert_Color
        (Frame.Rectangles (3).Color,
         Light.Cursor_BG,
         "cursor should use selected theme");
   end;

   Terminal.App.Renderer.Finalize (R);
end Theme_Config_Smoke;
