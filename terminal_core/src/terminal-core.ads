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

   Kitty_Image_Placeholder : constant Terminal.Common.Code_Point := 16#10EEEE#;

   type Graphics_ID is mod 2 ** 32;
   for Graphics_ID'Size use 32;

   type Graphics_Stream_ID is mod 2 ** 64;
   for Graphics_Stream_ID'Size use 64;
   type Graphics_Screen_Generation is mod 2 ** 64;
   for Graphics_Screen_Generation'Size use 64;
   type Graphics_Event_Sequence is mod 2 ** 64;
   for Graphics_Event_Sequence'Size use 64;
   type Graphics_Transaction_Generation is mod 2 ** 64;
   for Graphics_Transaction_Generation'Size use 64;
   type Graphics_Scroll_Sequence is mod 2 ** 64;
   for Graphics_Scroll_Sequence'Size use 64;

   Max_Graphics_Scroll_Events : constant := 4_096;
   type Graphics_Scroll_Direction is (Graphics_Scroll_Up, Graphics_Scroll_Down);
   type Graphics_Scroll_Event is record
      Sequence  : Graphics_Scroll_Sequence := 0;
      Direction : Graphics_Scroll_Direction := Graphics_Scroll_Up;
      Top       : Positive := 1;
      Bottom    : Positive := 1;
      Count     : Positive := 1;
   end record;
   type Graphics_Scroll_Event_Array is
     array (Positive range <>) of Graphics_Scroll_Event;
   type Graphics_Scroll_Event_Array_Access is
     access all Graphics_Scroll_Event_Array;

   --  Configured by the embedding application. The core owns framing and
   --  immediate query replies, but must never infer backend capabilities.
   type Graphics_Capability_Profile is record
      Kitty_Direct_RGB         : Boolean := False;
      Kitty_Direct_RGBA        : Boolean := False;
      Kitty_Indexed_RGB        : Boolean := False;
      Kitty_Indexed_RGBA       : Boolean := False;
      Kitty_Direct_PNG         : Boolean := False;
      Kitty_Zlib_Compression   : Boolean := False;
      Kitty_File_Transfer      : Boolean := False;
      Kitty_Temporary_Transfer : Boolean := False;
      Kitty_Shared_Memory      : Boolean := False;
      Sixel                    : Boolean := False;
      ITerm2_Inline_Images     : Boolean := False;
      ITerm2_File_Downloads    : Boolean := False;
   end record;

   --  Decoded identity carried by a Kitty Unicode placeholder cell.  The
   --  original code point, combining characters, and colors remain in Text and
   --  Style so ordinary terminal operations and multiplexers can still treat
   --  the placeholder as text.
   type Image_Cell_Metadata is record
      Is_Placeholder       : Boolean := False;
      Image_ID_Valid       : Boolean := False;
      Image_ID             : Graphics_ID := 0;
      Placement_ID         : Graphics_ID := 0;
      Image_Row            : Natural := 0;
      Image_Column         : Natural := 0;
      Row_Specified        : Boolean := False;
      Column_Specified     : Boolean := False;
      High_Byte_Specified  : Boolean := False;
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
      Image : Image_Cell_Metadata;
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
      Mouse_UTF8         : Boolean := False;
      Mouse_SGR          : Boolean := False;
      Mouse_URXVT        : Boolean := False;
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
      Sixel_Display_Mode : Boolean := False;
      Sixel_Private_Colors : Boolean := True;
      Sixel_Scrolls_Right : Boolean := False;
      --  DEC private mode 2048: report the size whenever it changes.
      In_Band_Resize     : Boolean := False;
      --  The active progressive keyboard enhancement flags, as the top of
      --  the active screen's stack holds them. Only bit 1, disambiguate
      --  escape codes, is supported.
      Keyboard_Flags     : Natural range 0 .. 31 := 0;
   end record;

   --  The keyboard enhancement flags this terminal implements.
   Supported_Keyboard_Flags : constant := 1;

   type Ignored_Graphics_Protocol is
     (No_Graphics,
      Sixel_Graphics,
      Kitty_Graphics,
      ITerm2_Graphics);

   Max_Graphics_Preview_Length : constant := 128 * 1024;
   --  Compatibility snapshots retain only this bounded prefix.  Complete
   --  graphics commands are delivered through Read_Graphics_Event below.
   subtype Graphics_Preview_Length_Range is
     Natural range 0 .. Max_Graphics_Preview_Length;

   Max_Graphics_Transaction_Length : constant := 8 * 1024 * 1024;
   --  A conforming direct transfer may use thousands of 4096-byte APC
   --  chunks.  The byte quota is the primary memory bound; this separate
   --  count also bounds streams of payload-free commands.
   Max_Pending_Graphics_Events     : constant := 4_096;
   Max_Pending_Graphics_Bytes      : constant := 16 * 1024 * 1024;
   Max_Deferred_Input_Bytes        : constant := 16 * 1024 * 1024;
   Max_Graphics_Pixel_Dimension    : constant := 16_384;

   type Graphics_Resource_Limits is record
      Transaction_Length : Positive range 1 .. Max_Graphics_Transaction_Length :=
        Max_Graphics_Transaction_Length;
      Pending_Events : Positive range 1 .. Max_Pending_Graphics_Events :=
        Max_Pending_Graphics_Events;
      Pending_Bytes : Positive range 1 .. Max_Pending_Graphics_Bytes :=
        Max_Pending_Graphics_Bytes;
      Deferred_Input_Bytes : Positive range 1 .. Max_Deferred_Input_Bytes :=
        Max_Deferred_Input_Bytes;
      Pixel_Dimension : Positive range 1 .. Max_Graphics_Pixel_Dimension :=
        Max_Graphics_Pixel_Dimension;
   end record;

   Default_Graphics_Resource_Limits : constant Graphics_Resource_Limits :=
     (others => <>);

   type Graphics_Event is record
      Pending        : Boolean := False;
      Cancelled      : Boolean := False;
      Protocol       : Ignored_Graphics_Protocol := No_Graphics;
      Stream_ID      : Graphics_Stream_ID := 0;
      Sequence       : Graphics_Event_Sequence := 0;
      Transaction_Generation : Graphics_Transaction_Generation := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Graphics_Screen_Generation := 0;
      Scroll_Sequence : Graphics_Scroll_Sequence := 0;
      Sixel_Private_Colors : Boolean := True;
      Row            : Positive := 1;
      Col            : Positive := 1;
      Payload_Length : Natural := 0;
      Preview_Length : Graphics_Preview_Length_Range := 0;
      Preview        : String (1 .. Max_Graphics_Preview_Length) :=
        (others => ASCII.NUL);
   end record;

   type Kitty_Graphics_Result_Code is
     (Kitty_No_Response,
      Kitty_OK,
      Kitty_EINVAL,
      Kitty_ENOENT,
      Kitty_ENOMEM,
      Kitty_ENOSPC,
      Kitty_EBADF,
      Kitty_ENOTSUP,
      Kitty_ENOPARENT,
      Kitty_ECYCLE,
      Kitty_ETOODEEP);

   type Kitty_Graphics_Result is record
      Code               : Kitty_Graphics_Result_Code := Kitty_No_Response;
      Image_ID           : Graphics_ID := 0;
      Image_Number       : Graphics_ID := 0;
      Has_Image_Number   : Boolean := False;
      Placement_ID       : Graphics_ID := 0;
      Has_Placement_ID   : Boolean := False;
      Quiet              : Natural range 0 .. 2 := 0;
      Respond            : Boolean := True;
      Move_Cursor        : Boolean := False;
      Cursor_To_Line_Start : Boolean := False;
      Placement_Columns  : Positive := 1;
      Placement_Rows     : Positive := 1;
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
      Graphics_Stream : Graphics_Stream_ID := 0;
      Graphics_Transaction : Graphics_Transaction_Generation := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Graphics_Screen_Generation := 0;
      Scrollback_Offset : Natural := 0;
      Scrollback_Rows : Natural := 0;
      Graphics_Scroll_Current : Graphics_Scroll_Sequence := 0;
      Graphics_Scroll_Oldest : Graphics_Scroll_Sequence := 0;
      Graphics_Scroll_Count : Natural range 0 .. Max_Graphics_Scroll_Events := 0;
      Graphics_Scroll_Events : Graphics_Scroll_Event_Array_Access := null;
      Cells  : Cell_Array_Access := null;
      Dirty  : Dirty_Row_Array_Access := null;
      Image_Cell_Count : Natural := 0;
      Cursor : Cursor_State;
      Graphics : Graphics_Event;
   end record;

   type Terminal is limited private;

   procedure Initialize
     (T                : in out Terminal;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural := 10_000;
      Status           : out Initialize_Status);

   procedure Finalize (T : in out Terminal);

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

   procedure Set_Graphics_Capabilities
     (T       : in out Terminal;
      Profile : Graphics_Capability_Profile);

   procedure Set_Graphics_Stream_ID
     (T  : in out Terminal;
      ID : Graphics_Stream_ID);
   procedure Set_Graphics_Resource_Limits
     (T      : in out Terminal;
      Limits : Graphics_Resource_Limits);
   function Graphics_Resource_Limit
     (T : Terminal) return Graphics_Resource_Limits;

   function Snapshot (T : Terminal) return Render_Snapshot;
   --  Refresh an existing snapshot, retaining its backing arrays when their
   --  dimensions still match.  This is the allocation-free path for steady
   --  state rendering.
   procedure Snapshot
     (T : Terminal;
      S : in out Render_Snapshot);
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

   --  Complete graphics commands form a FIFO independent of the legacy
   --  preview in Render_Snapshot.  Read_Graphics_Event returns the event at
   --  the head and the next payload bytes.  End_Of_Event is true on the call
   --  that consumes the event; Event.Pending is false when the FIFO is empty.
   function Pending_Graphics_Event_Count (T : Terminal) return Natural;
   function Pending_Graphics_Byte_Count (T : Terminal) return Natural;

   procedure Peek_Graphics_Event
     (T     : Terminal;
      Event : out Graphics_Event);

   --  Return a stable copy of the current FIFO head's complete payload.
   --  This is intentionally separate from the bounded snapshot preview.
   function Graphics_Event_Payload
     (T     : Terminal;
      Event : Graphics_Event) return String;

   procedure Discard_Graphics_Event (T : in out Terminal);

   --  Atomically queues the backend result for the current Kitty command and
   --  releases that FIFO head. A stale/mismatched event is left untouched.
   procedure Complete_Graphics_Event
     (T      : in out Terminal;
      Event  : Graphics_Event;
      Result : Kitty_Graphics_Result);

   procedure Read_Graphics_Event
     (T            : in out Terminal;
      Event        : out Graphics_Event;
      Buffer       : out Core_Byte_Array;
      Last         : out Natural;
      End_Of_Event : out Boolean);

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
   Max_OSC_Payload_Length : constant := 1024 * 1024;
   Max_Ignored_String_Preview_Length : constant := 128 * 1024;
   subtype Ignored_String_Index is
     Positive range 1 .. Max_Ignored_String_Preview_Length;
   type Ignored_String_Buffer is
     array (Ignored_String_Index) of Standard.Character;

   type String_Access is access all String;
   type Core_Byte_Array_Access is access all Core_Byte_Array;
   type Graphics_Event_Node;
   type Graphics_Event_Node_Access is access Graphics_Event_Node;
   type Graphics_Event_Node is record
      Protocol       : Ignored_Graphics_Protocol := No_Graphics;
      Cancelled      : Boolean := False;
      Stream_ID      : Graphics_Stream_ID := 0;
      Sequence       : Graphics_Event_Sequence := 0;
      Transaction_Generation : Graphics_Transaction_Generation := 0;
      Blocks_Input   : Boolean := False;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Graphics_Screen_Generation := 0;
      Scroll_Sequence : Graphics_Scroll_Sequence := 0;
      Sixel_Private_Colors : Boolean := True;
      Row            : Positive := 1;
      Col            : Positive := 1;
      Payload_Length : Natural := 0;
      Payload        : String_Access := null;
      Read_Offset    : Natural := 0;
      Next           : Graphics_Event_Node_Access := null;
   end record;

   Max_Keyboard_Stack_Depth : constant := 8;

   type Keyboard_Flag_Array is array (1 .. Max_Keyboard_Stack_Depth) of Natural range 0 .. 31;

   --  Pushed keyboard flags, the last pushed in Flags (Depth).
   type Keyboard_Stack is record
      Flags : Keyboard_Flag_Array := (others => 0);
      Depth : Natural range 0 .. Max_Keyboard_Stack_Depth := 0;
   end record;

   --  The main and the alternate screen keep stacks of their own.
   type Keyboard_Stack_Pair is array (Boolean) of Keyboard_Stack;

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
      --  Physical index (0-based) of the oldest scrollback row, so the store is
      --  a ring buffer: appending when full advances this head instead of
      --  memmoving every row down. Stays 0 until the buffer first fills, so the
      --  not-full layout is unchanged.
      Scrollback_Head  : Natural := 0;

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
      --  Indexed by whether the alternate screen is active.
      Keyboard_Stacks : Keyboard_Stack_Pair;
      G0_Charset    : Charset_Kind := ASCII_Charset;
      G1_Charset    : Charset_Kind := ASCII_Charset;
      G2_Charset    : Charset_Kind := ASCII_Charset;
      G3_Charset    : Charset_Kind := ASCII_Charset;
      Active_Charset : Charset_Slot := G0;
      Charset_Target : Charset_Slot := G0;
      Single_Shift_Charset : Charset_Slot := G2;
      Diag          : Diagnostic_Snapshot;
      Last_Graphics : Graphics_Event;
      Graphics_Head : Graphics_Event_Node_Access := null;
      Graphics_Tail : Graphics_Event_Node_Access := null;
      Graphics_Event_Count : Natural range 0 .. Max_Pending_Graphics_Events := 0;
      Graphics_Byte_Count  : Natural range 0 .. Max_Pending_Graphics_Bytes := 0;
      Graphics_Stream      : Graphics_Stream_ID := 0;
      Primary_Graphics_Generation : Graphics_Screen_Generation := 0;
      Alternate_Graphics_Generation : Graphics_Screen_Generation := 0;
      Primary_Graphics_Scroll_Sequence : Graphics_Scroll_Sequence := 0;
      Alternate_Graphics_Scroll_Sequence : Graphics_Scroll_Sequence := 0;
      Primary_Graphics_Scroll_Head : Natural range 0 .. Max_Graphics_Scroll_Events - 1 := 0;
      Alternate_Graphics_Scroll_Head : Natural range 0 .. Max_Graphics_Scroll_Events - 1 := 0;
      Primary_Graphics_Scroll_Count : Natural range 0 .. Max_Graphics_Scroll_Events := 0;
      Alternate_Graphics_Scroll_Count : Natural range 0 .. Max_Graphics_Scroll_Events := 0;
      Primary_Graphics_Scroll_Events :
        Graphics_Scroll_Event_Array_Access := null;
      Alternate_Graphics_Scroll_Events :
        Graphics_Scroll_Event_Array_Access := null;
      Next_Graphics_Sequence : Graphics_Event_Sequence := 1;
      Graphics_Transaction : Graphics_Transaction_Generation := 1;
      Graphics_Input_Blocked : Boolean := False;
      Graphics_Queue_Backpressure : Boolean := False;
      Graphics_Queue_Overflowed : Boolean := False;
      Kitty_Chunk_Active : Boolean := False;
      Kitty_Chunk_Blocks_Input : Boolean := False;
      Kitty_Chunk_Action : Standard.Character := 't';
      Kitty_Chunk_Data : String_Access := null;
      Kitty_Chunk_Length : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      Kitty_Chunk_Capacity : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      Deferred_Input : Core_Byte_Array_Access := null;
      Deferred_Input_Length : Natural range 0 .. Max_Deferred_Input_Bytes := 0;
      Deferred_Input_Capacity : Natural range 0 .. Max_Deferred_Input_Bytes := 0;
      Graphics_Transfer : String_Access := null;
      Graphics_Limits : Graphics_Resource_Limits :=
        Default_Graphics_Resource_Limits;
      Graphics_Transfer_Length : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      Graphics_Transfer_Capacity : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      ITerm2_Multipart : String_Access := null;
      ITerm2_Multipart_Length : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      ITerm2_Multipart_Capacity : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      ITerm2_Multipart_Active : Boolean := False;
      Graphics_Capabilities : Graphics_Capability_Profile := (others => False);
      Last_Printable : Common.Code_Point := 0;
      Has_Last_Printable : Boolean := False;
      Window_Title  : Title_Text;
      Saved_Window_Title : Title_Text;
      Saved_Window_Title_Valid : Boolean := False;
      Clipboard_Data : Clipboard_Request;
      Current_Link : Hyperlink;
      Responses     : Response_Buffer := (others => 0);
      Response_Length : Natural range 0 .. Max_Response_Length := 0;
      Response_Transaction_Start : Natural range 0 .. Max_Response_Length := 0;
      Response_Transaction_Active : Boolean := False;
      Response_Transaction_Overflowed : Boolean := False;

      State         : Parser_State := Ground;
      CSI_Private   : Standard.Character := ASCII.NUL;
      CSI_Params    : Param_Array := (others => 0);
      CSI_Set       : Param_Set_Array := (others => False);
      CSI_Separators : Param_Separator_Array := (others => ASCII.NUL);
      CSI_Count     : Natural := 0;
      CSI_Intermediates : CSI_Intermediate_Array := (others => ASCII.NUL);
      CSI_Intermediate_Count : Natural := 0;
      OSC_Data      : String_Access := null;
      OSC_Count     : Natural := 0;
      OSC_Capacity  : Natural range 0 .. Max_OSC_Payload_Length := 0;
      Ignored_String_Data : Ignored_String_Buffer := (others => ASCII.NUL);
      Ignored_String_Count : Natural := 0;
      Ignored_String_Is_DCS : Boolean := False;
      Ignored_String_Is_APC : Boolean := False;

      UTF8_Need     : Natural := 0;
      UTF8_Seen     : Natural := 0;
      UTF8_Accum    : Natural := 0;
      UTF8_Min      : Natural := 0;
   end record;
end Terminal.Core;
