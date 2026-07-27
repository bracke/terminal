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

   type Underline_Style is
     (Underline_Single,
      Underline_Double,
      Underline_Curly,
      Underline_Dotted,
      Underline_Dashed);

   type Style is record
      Foreground : Color;
      Background : Color;
      Underline_Color : Color;
      Underline_Kind : Underline_Style := Underline_Single;
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
   Max_Cluster_Attachments : constant := 8;
   subtype Cluster_Attachment_Count is Natural range 0 .. Max_Cluster_Attachments;
   subtype Cluster_Attachment_Index is Positive range 1 .. Max_Cluster_Attachments;
   type Cluster_Attachment_Array is
     array (Cluster_Attachment_Index) of Terminal.Common.Code_Point;

   type Text_Cluster is record
      Code_Point : Terminal.Common.Code_Point := 0;
      Width      : Cell_Width := Width_One;
      Attachment_Count : Cluster_Attachment_Count := 0;
      Attachments : Cluster_Attachment_Array := (others => 0);
   end record;

   Max_Hyperlink_URI_Length : constant := 512;
   Max_Hyperlink_ID_Length  : constant := 128;
   subtype Hyperlink_URI_Length_Range is
     Natural range 0 .. Max_Hyperlink_URI_Length;
   subtype Hyperlink_ID_Length_Range is
     Natural range 0 .. Max_Hyperlink_ID_Length;

   type Hyperlink is record
      Active     : Boolean := False;
      URI_Length : Hyperlink_URI_Length_Range := 0;
      URI        : String (1 .. Max_Hyperlink_URI_Length) := (others => ' ');
      ID_Length  : Hyperlink_ID_Length_Range := 0;
      ID         : String (1 .. Max_Hyperlink_ID_Length) := (others => ' ');
   end record;

   type Cell is record
      Kind  : Cell_Kind := Empty;
      Text  : Text_Cluster;
      Style : Cell_Style;
      Link  : Hyperlink;
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
      Application_Keypad : Boolean := False;
      Backarrow_Key_Backspace : Boolean := False;
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
      Keyboard_Locked    : Boolean := False;
      Insert_Mode        : Boolean := False;
      Linefeed_New_Line  : Boolean := False;
   end record;

   type Ignored_Graphics_Protocol is
     (No_Graphics,
      Sixel_Graphics,
      Kitty_Graphics,
      ITerm2_Graphics);

   Max_Graphics_Preview_Length : constant := 128 * 1024;
   subtype Graphics_Preview_Length_Range is
     Natural range 0 .. Max_Graphics_Preview_Length;

   type Graphics_Event is record
      Pending        : Boolean := False;
      Protocol       : Ignored_Graphics_Protocol := No_Graphics;
      Row            : Positive := 1;
      Col            : Positive := 1;
      Payload_Length : Natural := 0;
      Preview_Length : Graphics_Preview_Length_Range := 0;
      Preview        : String (1 .. Max_Graphics_Preview_Length) :=
        (others => ASCII.NUL);
   end record;

   type Diagnostic_Snapshot is record
      Malformed_UTF8       : Natural := 0;
      Ignored_Escape       : Natural := 0;
      Parser_Overflow      : Natural := 0;
      Queue_Overflow       : Natural := 0;
      Unsupported_Sequence : Natural := 0;
      Text_Cluster_Overflow : Natural := 0;
      Graphics_Protocol_Ignored : Natural := 0;
      Sixel_Ignored : Natural := 0;
      Kitty_Graphics_Ignored : Natural := 0;
      ITerm2_Image_Ignored : Natural := 0;
      Multiplexer_Passthrough : Natural := 0;
      Last_Graphics_Protocol  : Ignored_Graphics_Protocol := No_Graphics;
      Last_Graphics_Payload_Length : Natural := 0;
   end record;

   Max_Status_Label_Length : constant := 96;

   Max_Title_Length : constant := 256;
   subtype Title_Length_Range is Natural range 0 .. Max_Title_Length;

   type Title_Text is record
      Length : Title_Length_Range := 0;
      Text   : String (1 .. Max_Title_Length) := (others => ' ');
   end record;

   Max_Clipboard_Length : constant := 3072;
   subtype Clipboard_Length_Range is Natural range 0 .. Max_Clipboard_Length;

   type Clipboard_Operation is (Clipboard_Set, Clipboard_Query);
   type Clipboard_Target is
     (Clipboard_Clipboard,
      Clipboard_Primary,
      Clipboard_Selection);

   type Clipboard_Request is record
      Pending : Boolean := False;
      Operation : Clipboard_Operation := Clipboard_Set;
      Target : Clipboard_Target := Clipboard_Clipboard;
      Length  : Clipboard_Length_Range := 0;
      Text    : String (1 .. Max_Clipboard_Length) := (others => ' ');
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
      Graphics : Graphics_Event;
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
   function Initialize_Status_Label (Status : Initialize_Status) return String;
   function Feed_Status_Label (Status : Feed_Status) return String;
   function Diagnostics_Status_Label
     (Diagnostics : Diagnostic_Snapshot) return String;
   function Title (T : Terminal) return Title_Text;
   function Clipboard (T : Terminal) return Clipboard_Request;
   procedure Clear_Clipboard (T : in out Terminal);
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

   function Is_Renderable_Attachment
     (CP : Common.Code_Point) return Boolean;

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
      Coding_System,
      Single_Shift,
      Screen_Alignment);
   subtype Param_Index is Positive range 1 .. 16;
   type Param_Array is array (Param_Index) of Natural;
   type Param_Set_Array is array (Param_Index) of Boolean;
   type Param_Separator_Array is array (Param_Index) of Standard.Character;
   subtype CSI_Intermediate_Index is Positive range 1 .. 4;
   type CSI_Intermediate_Array is
     array (CSI_Intermediate_Index) of Standard.Character;

   type Buffer_Kind is (Primary, Alternate);
   type Charset_Kind is (ASCII_Charset, DEC_Special_Graphics);
   type Charset_Slot is (G0, G1, G2, G3);
   Max_Response_Length : constant := Max_Title_Length + 16;
   subtype Response_Index is Positive range 1 .. Max_Response_Length;
   type Response_Buffer is
     array (Response_Index) of Common.Bytes.Byte;
   Max_OSC_Payload_Length : constant := 128 * 1024;
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
      Saved_G0_Charset : Charset_Kind := ASCII_Charset;
      Saved_G1_Charset : Charset_Kind := ASCII_Charset;
      Saved_G2_Charset : Charset_Kind := ASCII_Charset;
      Saved_G3_Charset : Charset_Kind := ASCII_Charset;
      Saved_Active_Charset : Charset_Slot := G0;
      Pending_Wrap  : Boolean := False;
      Top_Margin    : Positive := 1;
      Bottom_Margin : Positive := 1;
      Current_Style : Style;
      Current_Modes : Mode_Snapshot;
      G0_Charset    : Charset_Kind := ASCII_Charset;
      G1_Charset    : Charset_Kind := ASCII_Charset;
      G2_Charset    : Charset_Kind := ASCII_Charset;
      G3_Charset    : Charset_Kind := ASCII_Charset;
      Active_Charset : Charset_Slot := G0;
      Charset_Target : Charset_Slot := G0;
      Single_Shift_Charset : Charset_Slot := G2;
      Diag          : Diagnostic_Snapshot;
      Last_Graphics : Graphics_Event;
      Last_Printable : Common.Code_Point := 0;
      Has_Last_Printable : Boolean := False;
      Window_Title  : Title_Text;
      Saved_Window_Title : Title_Text;
      Saved_Window_Title_Valid : Boolean := False;
      Clipboard_Data : Clipboard_Request;
      Current_Link : Hyperlink;
      Responses     : Response_Buffer := (others => 0);
      Response_Length : Natural range 0 .. Max_Response_Length := 0;

      State         : Parser_State := Ground;
      CSI_Private   : Standard.Character := ASCII.NUL;
      CSI_Params    : Param_Array := (others => 0);
      CSI_Set       : Param_Set_Array := (others => False);
      CSI_Separators : Param_Separator_Array := (others => ASCII.NUL);
      CSI_Count     : Natural := 0;
      CSI_Intermediates : CSI_Intermediate_Array := (others => ASCII.NUL);
      CSI_Intermediate_Count : Natural := 0;
      OSC_Data      : OSC_Buffer := (others => ASCII.NUL);
      OSC_Count     : Natural := 0;
      Ignored_String_Data : OSC_Buffer := (others => ASCII.NUL);
      Ignored_String_Count : Natural := 0;
      Ignored_String_Is_DCS : Boolean := False;
      Ignored_String_Is_APC : Boolean := False;

      UTF8_Need     : Natural := 0;
      UTF8_Seen     : Natural := 0;
      UTF8_Accum    : Natural := 0;
      UTF8_Min      : Natural := 0;
   end record;
end Terminal.Core;
