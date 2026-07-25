with Terminal.Common;
with Terminal.Common.Bytes;

package Terminal.Core is
   type Initialize_Status is
     (Ok,
      Invalid_Size,
      Invalid_Scrollback_Limit,
      Allocation_Failed);

   type Feed_Status is
     (Ok,
      Parser_Recovered,
      Parser_Overflow,
      Invalid_State);

   type Resize_Status is
     (Ok,
      Invalid_Size,
      Allocation_Failed);

   type Color_Kind is (Default, Indexed, RGB);

   type Color is record
      Kind  : Color_Kind := Default;
      Index : Natural range 0 .. 255 := 0;
      R     : Natural range 0 .. 255 := 0;
      G     : Natural range 0 .. 255 := 0;
      B     : Natural range 0 .. 255 := 0;
   end record;

   type Style is record
      Foreground : Color;
      Background : Color;
      Bold       : Boolean := False;
      Faint      : Boolean := False;
      Blink      : Boolean := False;
      Italic     : Boolean := False;
      Underline  : Boolean := False;
      Strikethrough : Boolean := False;
      Overline   : Boolean := False;
      Conceal    : Boolean := False;
      Inverse    : Boolean := False;
   end record;
   subtype Cell_Style is Style;

   type Cell_Kind is (Empty, Character, Wide_Continuation);
   type Cell_Width is (Width_Zero, Width_One, Width_Two);

   type Text_Cluster is record
      Code_Point : Terminal.Common.Code_Point := 0;
      Width      : Cell_Width := Width_One;
   end record;

   type Cell is record
      Kind  : Cell_Kind := Empty;
      Text  : Text_Cluster;
      Style : Cell_Style;
   end record;

   type Cursor_Shape is (Cursor_Block, Cursor_Underline, Cursor_Bar);

   type Cursor_State is record
      Row     : Positive := 1;
      Col     : Positive := 1;
      Visible : Boolean := True;
      Shape   : Cursor_Shape := Cursor_Block;
      Blinking : Boolean := False;
   end record;

   type Mode_Snapshot is record
      Application_Cursor : Boolean := False;
      Bracketed_Paste    : Boolean := False;
      Mouse_Button       : Boolean := False;
      Mouse_Drag         : Boolean := False;
      Mouse_Any_Event    : Boolean := False;
      Mouse_SGR          : Boolean := False;
      Focus_Reporting    : Boolean := False;
      Synchronized_Update : Boolean := False;
      Alternate_Screen   : Boolean := False;
      Origin_Mode        : Boolean := False;
      Autowrap           : Boolean := True;
      Cursor_Visible     : Boolean := True;
      Cursor_Blinking    : Boolean := False;
      Insert_Mode        : Boolean := False;
   end record;

   type Diagnostic_Snapshot is record
      Malformed_UTF8       : Natural := 0;
      Ignored_Escape       : Natural := 0;
      Parser_Overflow      : Natural := 0;
      Queue_Overflow       : Natural := 0;
      Unsupported_Sequence : Natural := 0;
   end record;

   Max_Title_Length : constant := 256;
   subtype Title_Length_Range is Natural range 0 .. Max_Title_Length;

   type Title_Text is record
      Length : Title_Length_Range := 0;
      Text   : String (1 .. Max_Title_Length) := (others => ' ');
   end record;

   type Cell_Array is array (Positive range <>) of Cell;
   type Dirty_Row_Array is array (Positive range <>) of Boolean;
   type Tab_Stop_Array is array (Positive range <>) of Boolean;
   subtype Core_Byte_Array is Terminal.Common.Bytes.Byte_Array;

   type Cell_Array_Access is access all Cell_Array;
   type Dirty_Row_Array_Access is access all Dirty_Row_Array;
   type Tab_Stop_Array_Access is access all Tab_Stop_Array;

   type Render_Snapshot is record
      Rows   : Natural := 0;
      Cols   : Natural := 0;
      Cells  : Cell_Array_Access := null;
      Dirty  : Dirty_Row_Array_Access := null;
      Cursor : Cursor_State;
   end record;

   type Terminal is limited private;

   procedure Initialize
     (T                : out Terminal;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural := 10_000;
      Status           : out Initialize_Status);

   procedure Feed
      (T      : in out Terminal;
      Data   : Core_Byte_Array;
      Status : out Feed_Status);

   procedure Resize
     (T      : in out Terminal;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Resize_Status);

   procedure Set_Cell_Pixel_Size
     (T      : in out Terminal;
      Width  : Positive;
      Height : Positive);

   procedure Set_Window_Pixel_Size
     (T      : in out Terminal;
      Width  : Natural;
      Height : Natural);

   function Snapshot (T : Terminal) return Render_Snapshot;
   procedure Release (S : in out Render_Snapshot);
   function Modes (T : Terminal) return Mode_Snapshot;
   function Diagnostics (T : Terminal) return Diagnostic_Snapshot;
   function Title (T : Terminal) return Title_Text;
   function Scrollback_Row_Count (T : Terminal) return Natural;
   function Pending_Response_Length (T : Terminal) return Natural;

   procedure Read_Response
     (T      : in out Terminal;
      Buffer : out Common.Bytes.Byte_Array;
      Last   : out Natural);

   procedure Clear_Damage (T : in out Terminal);

   function Cell_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell;

   function Scrollback_Cell_At
     (T   : Terminal;
      Row : Positive;
      Col : Positive) return Cell;

private
   type Parser_State is
     (Ground,
      Escape,
      CSI,
      OSC,
      OSC_Escape,
      OSC_Overflow,
      OSC_Overflow_Escape,
      Ignored_String,
      Ignored_String_Escape,
      Ignored_String_Overflow,
      Ignored_String_Overflow_Escape,
      Charset,
      Screen_Alignment);
   subtype Param_Index is Positive range 1 .. 16;
   type Param_Array is array (Param_Index) of Natural;
   type Param_Set_Array is array (Param_Index) of Boolean;
   subtype CSI_Intermediate_Index is Positive range 1 .. 4;
   type CSI_Intermediate_Array is
     array (CSI_Intermediate_Index) of Standard.Character;

   type Buffer_Kind is (Primary, Alternate);
   Max_Response_Length : constant := Max_Title_Length + 16;
   subtype Response_Index is Positive range 1 .. Max_Response_Length;
   type Response_Buffer is
     array (Response_Index) of Common.Bytes.Byte;
   Max_OSC_Payload_Length : constant := 4096;
   subtype OSC_Index is Positive range 1 .. Max_OSC_Payload_Length;
   type OSC_Buffer is array (OSC_Index) of Standard.Character;

   type Terminal is limited record
      Initialized      : Boolean := False;
      Rows             : Positive := 1;
      Cols             : Positive := 1;
      Cell_Pixel_Width : Natural := 0;
      Cell_Pixel_Height : Natural := 0;
      Window_Pixel_Width : Natural := 0;
      Window_Pixel_Height : Natural := 0;
      Scrollback_Limit : Natural := 10_000;
      Scrollback_Rows  : Natural := 0;

      Primary_Cells : Cell_Array_Access := null;
      Alt_Cells     : Cell_Array_Access := null;
      Scrollback    : Cell_Array_Access := null;
      Dirty         : Dirty_Row_Array_Access := null;
      Tab_Stops     : Tab_Stop_Array_Access := null;

      Active        : Buffer_Kind := Primary;
      Cursor_Row    : Positive := 1;
      Cursor_Col    : Positive := 1;
      Current_Cursor_Shape : Cursor_Shape := Cursor_Block;
      Current_Cursor_Blinking : Boolean := False;
      Saved_Row     : Positive := 1;
      Saved_Col     : Positive := 1;
      Saved_Style   : Style;
      Pending_Wrap  : Boolean := False;
      Top_Margin    : Positive := 1;
      Bottom_Margin : Positive := 1;
      Current_Style : Style;
      Current_Modes : Mode_Snapshot;
      Diag          : Diagnostic_Snapshot;
      Last_Printable : Common.Code_Point := 0;
      Has_Last_Printable : Boolean := False;
      Window_Title  : Title_Text;
      Responses     : Response_Buffer := (others => 0);
      Response_Length : Natural range 0 .. Max_Response_Length := 0;

      State         : Parser_State := Ground;
      CSI_Private   : Standard.Character := ASCII.NUL;
      CSI_Params    : Param_Array := (others => 0);
      CSI_Set       : Param_Set_Array := (others => False);
      CSI_Count     : Natural := 0;
      CSI_Intermediates : CSI_Intermediate_Array := (others => ASCII.NUL);
      CSI_Intermediate_Count : Natural := 0;
      OSC_Data      : OSC_Buffer := (others => ASCII.NUL);
      OSC_Count     : Natural := 0;
      Ignored_String_Count : Natural := 0;

      UTF8_Need     : Natural := 0;
      UTF8_Seen     : Natural := 0;
      UTF8_Accum    : Common.Code_Point := 0;
      UTF8_Min      : Natural := 0;
   end record;
end Terminal.Core;
