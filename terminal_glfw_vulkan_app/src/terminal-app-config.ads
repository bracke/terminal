with Terminal.App.Theme;

package Terminal.App.Config is
   Max_Status_Label_Length : constant := 128;
   Default_Scrollback_Limit : constant Natural := 10_000;
   Max_Scrollback_Limit : constant Natural := 100_000;
   Default_Wheel_Scroll_Lines : constant Positive := 3;
   Max_Wheel_Scroll_Lines : constant Positive := 100;
   Default_Window_Width : constant Positive := 960;
   Default_Window_Height : constant Positive := 600;
   Max_Window_Dimension : constant Positive := 16_384;
   Default_Startup_Rows : constant Positive := 24;
   Default_Startup_Cols : constant Positive := 80;
   Max_Startup_Cells : constant Positive := 1_000;

   type Config is record
      Color_Theme : Terminal.App.Theme.Theme_Name :=
        Terminal.App.Theme.Default_Dark;
      Scrollback_Limit : Natural := Default_Scrollback_Limit;
      Wheel_Scroll_Lines : Positive := Default_Wheel_Scroll_Lines;
      Window_Width : Positive := Default_Window_Width;
      Window_Height : Positive := Default_Window_Height;
      Startup_Rows : Positive := Default_Startup_Rows;
      Startup_Cols : Positive := Default_Startup_Cols;
   end record;

   type Line_Status is
     (Accepted,
      Ignored_Blank,
      Ignored_Comment,
      Missing_Separator,
      Unknown_Key,
      Invalid_Value);

   procedure Apply_Line
     (C      : in out Config;
      Line   : String;
      Status : out Line_Status);
   procedure Apply_Line
     (C        : in out Config;
      Line     : String;
      Accepted : out Boolean);
   procedure Load (C : out Config);
   function Active_Theme (C : Config) return Terminal.App.Theme.Theme;
   function Image (C : Config) return String;
   function Line_Status_Label (Status : Line_Status) return String;
   function Status_Label (C : Config) return String;
end Terminal.App.Config;
