with Terminal.Common.Base64;
with Terminal.Common.Counters;
with Terminal.Common.Identity;
with Terminal.Common.Sixel;
with Terminal.Core.Character_Properties;
with Terminal.Core.Cleanup_Diagnostics;
with Terminal.Core.Parser;
with Terminal.Core.Parser_Execution;
with Terminal.Core.Parser_Primitives;
with Terminal.Core.Graphics_Runtime;
with Terminal.Core.Graphics_Events;
with Terminal.Core.Graphics_Scrolling;
with Terminal.Core.Hyperlink_Store;
with Terminal.Core.Lifecycle;
with Terminal.Core.Parser_Buffers;
with Terminal.Core.Response_Facade;
with Terminal.Core.Response_Queries;
with Terminal.Core.Scrollback_Storage;
with Terminal.Core.Screen_Rows;
with Terminal.Core.Snapshot_Access;
with Terminal.Core.Snapshot_Cell_Storage;
with Terminal.Core.State_Access;
with Terminal.Core.Storage;

package body Terminal.Core is
   use Common;
   use type Common.Base64.Decoder_Status;

   type Hyperlink_Order is (Before, Equal, After);

   function Compare_Hyperlinks
     (Left, Right : Hyperlink) return Hyperlink_Order
   is
      Common_Length : Natural;
   begin
      if Left.Active /= Right.Active then
         return (if Left.Active then After else Before);
      elsif not Left.Active then
         return Equal;
      end if;

      Common_Length := Natural'Min (Left.URI_Length, Right.URI_Length);
      for I in 1 .. Common_Length loop
         if Left.URI (I) /= Right.URI (I) then
            return (if Left.URI (I) < Right.URI (I) then Before else After);
         end if;
      end loop;
      if Left.URI_Length /= Right.URI_Length then
         return (if Left.URI_Length < Right.URI_Length then Before else After);
      end if;

      Common_Length := Natural'Min (Left.ID_Length, Right.ID_Length);
      for I in 1 .. Common_Length loop
         if Left.ID (I) /= Right.ID (I) then
            return (if Left.ID (I) < Right.ID (I) then Before else After);
         end if;
      end loop;
      if Left.ID_Length /= Right.ID_Length then
         return (if Left.ID_Length < Right.ID_Length then Before else After);
      end if;
      return Equal;
   end Compare_Hyperlinks;

   function Same_Hyperlink (Left, Right : Hyperlink) return Boolean is
     (Compare_Hyperlinks (Left, Right) = Equal);

   function Stored_Hyperlink_Less
     (Left, Right : Stored_Hyperlink_Access) return Boolean
   is
   begin
      if Left = null then
         return Right /= null;
      elsif Right = null then
         return False;
      else
         return Compare_Hyperlinks (Left.Value, Right.Value) = Before;
      end if;
   end Stored_Hyperlink_Less;

   procedure Increment_Saturating (Value : in out Natural) renames
     Common.Counters.Increment_Saturating;

   function Append_Decimal_Digit
     (Value : Natural;
      Digit : Natural;
      Limit : Natural) return Natural
   is
   begin
      if Digit > 9
        or else Digit > Limit
        or else Value > (Limit - Digit) / 10
      then
         return Limit;
      end if;
      return Value * 10 + Digit;
   end Append_Decimal_Digit;

   procedure Enqueue_Graphics_Event
     (T              : in out Terminal;
      Protocol       : Graphics_Protocol_Kind;
      Row            : Positive;
      Col            : Positive;
      Payload        : String;
      Cancelled      : Boolean := False)
   is separate;

   function Index
     (T : Terminal; Row : Positive; Col : Positive) return Positive
      renames Screen_Rows.Cell_Index;

   function Active_Cells (T : Terminal'Class) return Stored_Cell_Array_Access
      renames Screen_Rows.Cells;

   function Public_Cell (Value : Stored_Cell) return Cell is
     (Includes_Link => True,
      Kind  => Value.Kind,
      Text  =>
        (if Value.Clipped_Wide
         then (Value.Text with delta Width => Width_One)
         else Value.Text),
      Style => Value.Style,
      Link  => (if Value.Link = null then (others => <>) else Value.Link.Value),
      Image => Value.Image);


   function Image_Diacritic_Value
     (CP    : Common.Code_Point;
      Value : out Natural) return Boolean is separate;

   type Graphics_Protocol is
     (Graphics_Sixel,
      Graphics_Kitty,
      Graphics_ITerm2);

   procedure Note_Graphics_Protocol
     (T        : in out Terminal;
      Protocol : Graphics_Protocol;
      Payload_Length : Natural;
      Preview        : String := "";
      At_Row         : Natural := 0;
      At_Col         : Natural := 0;
      Kitty_Validation_Error : Boolean := False)
   is separate;

   type Kitty_Chunk_Control is record
      Valid            : Boolean := False;
      More_Specified   : Boolean := False;
      More             : Boolean := False;
      More_Value_Index : Natural := 0;
      Data_First       : Natural := 0;
      Action           : Standard.Character := 't';
      Transmission     : Standard.Character := 'd';
      Quiet_Specified  : Boolean := False;
      Quiet            : Natural range 0 .. 2 := 0;
   end record;

   function Parse_Kitty_Chunk_Control
     (Payload       : String;
      Continuation  : Boolean;
      Initial_Action : Standard.Character := 't') return Kitty_Chunk_Control
   is separate;

   procedure Process_Kitty_Graphics_APC
     (T       : in out Terminal;
      Payload : String) is separate;

   procedure Reject_Kitty_Chunk_Interleave (T : in out Terminal) is
   begin
      if not T.Graphics.Kitty_Chunk_Active then
         return;
      end if;
      if T.Graphics.Kitty_Chunk_Data /= null and then T.Graphics.Kitty_Chunk_Length > 0 then
         Note_Graphics_Protocol
           (T,
            Graphics_Kitty,
            T.Graphics.Kitty_Chunk_Length,
            T.Graphics.Kitty_Chunk_Data (1 .. T.Graphics.Kitty_Chunk_Length),
            Kitty_Validation_Error => True);
      end if;
      Graphics_Runtime.Advance_Graphics_Transaction (T.Graphics);
      Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
   end Reject_Kitty_Chunk_Interleave;

   function OSC_Slice
     (T : Terminal; First : Positive; Last : Natural) return String
     renames Parser_Buffers.OSC_Slice;

   function Ignored_String_Slice
     (T : Terminal; First : Positive; Last : Natural) return String
     renames Parser_Buffers.Ignored_String_Slice;

   procedure Reset_Graphics_Scroll
     (T : in out Terminal;
      Alternate_Screen : Boolean)
     renames Graphics_Scrolling.Reset;

   procedure Note_Graphics_Scroll
     (T         : in out Terminal;
      Direction : Graphics_Scroll_Direction;
      Top       : Positive;
      Bottom    : Positive;
      Count     : Positive)
     renames Graphics_Scrolling.Note;

   procedure New_Line (T : in out Terminal);
   procedure Append_Response_Char
     (T  : in out Terminal;
      Ch : Standard.Character)
     renames Response_Facade.Append_Character;
   procedure Append_Response_String
     (T    : in out Terminal;
      Text : String)
     renames Response_Facade.Append_String;
   procedure Begin_Response (T : in out Terminal)
     renames Response_Facade.Begin_Transaction;
   procedure End_Response (T : in out Terminal)
     renames Response_Facade.End_Transaction;
   procedure Append_Response_Natural
     (T : in out Terminal;
      N : Natural)
     renames Response_Facade.Append_Natural;
   procedure Append_Response_Graphics_ID
     (T : in out Terminal;
      Value : Graphics_ID)
     renames Response_Facade.Append_Graphics_ID;

   --  Make Current_Modes.Keyboard_Flags the top of the active screen's
   --  keyboard stack.
   procedure Refresh_Keyboard_Flags (T : in out Terminal);

   --  CSI 48 ; rows ; cols ; height ; width t, the in-band size report.
   procedure Queue_Resize_Report (T : in out Terminal);

   procedure Mark_Dirty (T : in out Terminal; Row : Positive)
      renames Screen_Rows.Mark_Dirty;

   procedure Mark_All_Dirty (T : in out Terminal)
      renames Screen_Rows.Mark_All_Dirty;

   procedure Mark_Cursor_Move
     (T       : in out Terminal;
      Old_Row : Positive)
      renames Screen_Rows.Mark_Cursor_Move;

   procedure Reset_Tab_Stops (T : in out Terminal)
      renames Screen_Rows.Reset_Tab_Stops;

   function Blank_Cell (Style : Cell_Style) return Stored_Cell
      renames Screen_Rows.Blank;

   procedure Clear_Row
     (T     : in out Terminal;
      Row   : Positive;
      First : Positive;
      Last  : Positive)
      renames Screen_Rows.Clear_Row;

   procedure Reset_Buffer
     (T : in out Terminal; Cells : Stored_Cell_Array_Access)
      renames Screen_Rows.Reset_Buffer;

   procedure Screen_Alignment_Test (T : in out Terminal)
      renames Screen_Rows.Screen_Alignment_Test;

   procedure Index_Control (T : in out Terminal) is
   begin
      New_Line (T);
   end Index_Control;

   procedure Next_Line_Control (T : in out Terminal) is
   begin
      T.Cursor_Col := 1;
      New_Line (T);
   end Next_Line_Control;

   procedure Reverse_Index_Control (T : in out Terminal) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      if T.Cursor_Row = T.Top_Margin then
         Scroll_Down_Region (T, T.Top_Margin, T.Bottom_Margin);
      elsif T.Cursor_Row > 1 then
         T.Cursor_Row := T.Cursor_Row - 1;
      end if;
      Mark_Cursor_Move (T, Old_Row);
   end Reverse_Index_Control;

   procedure Horizontal_Tab_Set (T : in out Terminal)
      renames Screen_Rows.Horizontal_Tab_Set;

   procedure Save_Cursor_State (T : in out Terminal)
      renames Screen_Rows.Save_Cursor_State;

   procedure Restore_Cursor_State (T : in out Terminal)
      renames Screen_Rows.Restore_Cursor_State;

   function Default_Modes
     (Alternate_Screen : Boolean := False) return Mode_Snapshot is
   begin
      return
        (Application_Cursor       => False,
         Application_Keypad       => False,
         Backarrow_Key_Backspace  => False,
         Bracketed_Paste          => False,
         Mouse_Button             => False,
         Mouse_Drag               => False,
         Mouse_Any_Event          => False,
         Mouse_UTF8               => False,
         Mouse_SGR                => False,
         Mouse_URXVT              => False,
         Focus_Reporting          => False,
         Synchronized_Update      => False,
         Alternate_Screen         => Alternate_Screen,
         Origin_Mode              => False,
         Autowrap                 => True,
         Cursor_Visible           => True,
         Cursor_Blinking          => False,
         Keyboard_Locked          => False,
         Insert_Mode              => False,
         Linefeed_New_Line        => False,
         Sixel_Display_Mode       => False,
         Sixel_Private_Colors     => True,
         Sixel_Scrolls_Right      => False,
         In_Band_Resize           => False,
         Keyboard_Flags           => 0);
   end Default_Modes;

   procedure Reset_Terminal (T : in out Terminal) is separate;

   procedure Allocate_Buffers
     (T      : in out Terminal;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Boolean) is separate;

   procedure Initialize
     (T                : in out Terminal;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural := 10_000;
      Status           : out Initialize_Status)
   is separate;

   overriding procedure Finalize (T : in out Terminal)
     renames Lifecycle.Finalize;

   procedure Append_OSC_Byte
     (T          : in out Terminal;
      Ch         : Standard.Character;
      Overflowed : in out Boolean)
     renames Parser_Buffers.Append_OSC_Byte;

   --  The private identity exchange that tells a program it runs in this
   --  terminal: asked with OSC 7701 ; q ST, answered with
   --  OSC 7701 ; v=<version> ; caps=<name>,... ST.
   Private_Identity_OSC : constant := 7701;

   procedure Queue_Identity_Report (T : in out Terminal) is
      First : Boolean := True;

      procedure Capability (Name : String; Present : Boolean) is
      begin
         if Present then
            if not First then
               Append_Response_Char (T, ',');
            end if;

            Append_Response_String (T, Name);
            First := False;
         end if;
      end Capability;
   begin
      Begin_Response (T);
      Append_Response_String (T, ASCII.ESC & "]7701;v=");
      Append_Response_Natural (T, Common.Identity.Identity_Protocol_Version);
      Append_Response_String (T, ";caps=");
      Capability
        ("kgfx",
         T.Graphics.Capabilities.Kitty_Direct_RGBA or else T.Graphics.Capabilities.Kitty_Direct_PNG);
      Capability ("kgfx-shm", T.Graphics.Capabilities.Kitty_Shared_Memory);
      Capability ("kgfx-jpeg", T.Graphics.Capabilities.Kitty_Direct_JPEG);
      Capability ("kgfx-gif", T.Graphics.Capabilities.Kitty_Direct_GIF);
      Capability ("kbd", True);
      Capability ("resize2048", True);
      Capability ("osc52", True);
      Append_Response_String (T, ASCII.ESC & "\");
      End_Response (T);
   end Queue_Identity_Report;

   procedure Finish_OSC (T : in out Terminal) is separate;

   procedure Append_Ignored_String_Byte
     (T          : in out Terminal;
      Ch         : Standard.Character;
      Overflowed : in out Boolean)
     renames Parser_Buffers.Append_Ignored_String_Byte;

   procedure Start_Ignored_String
     (T      : in out Terminal;
      Is_DCS : Boolean;
      Is_APC : Boolean := False)
     renames Parser_Buffers.Start_Ignored_String;

   function In_String_Control (State : Parser_State) return Boolean renames
     Parser_Primitives.In_String_Control;

   procedure Append_Scrollback_Row
     (T      : in out Terminal;
      Cells  : Stored_Cell_Array_Access;
      Source : Positive)
   is
   begin
      Increment_Saturating (T.History_Rows);
      Scrollback_Storage.Append_Row
        (T.Scrollback_State,
         T.Cols,
         T.Current_Style,
         T.Diag.Queue_Overflow,
         Cells,
         Source);
   end Append_Scrollback_Row;

   procedure Scroll_Up_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1)
   is separate;

   procedure Scroll_Down_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1)
   is separate;

   procedure New_Line (T : in out Terminal) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      T.Pending_Wrap := False;
      if T.Cursor_Row = T.Bottom_Margin then
         Scroll_Up_Region (T, T.Top_Margin, T.Bottom_Margin);
      elsif T.Cursor_Row < T.Rows then
         T.Cursor_Row := T.Cursor_Row + 1;
      end if;
      Mark_Cursor_Move (T, Old_Row);
   end New_Line;

   function Is_Wide (CP : Common.Code_Point) return Boolean renames
     Character_Properties.Is_Wide;
   function Is_Emoji_Variation_Base
     (CP : Common.Code_Point) return Boolean renames
       Character_Properties.Is_Emoji_Variation_Base;
   function Is_Keycap_Base (CP : Common.Code_Point) return Boolean renames
     Character_Properties.Is_Keycap_Base;
   function Is_Regional_Indicator
     (CP : Common.Code_Point) return Boolean renames
       Character_Properties.Is_Regional_Indicator;
   function Is_Emoji_Modifier
     (CP : Common.Code_Point) return Boolean renames
       Character_Properties.Is_Emoji_Modifier;

   function Is_Zero_Width (CP : Common.Code_Point) return Boolean is
      Image_Value : Natural;
   begin
      return
        Image_Diacritic_Value (CP, Image_Value)
        or else Character_Properties.Is_Zero_Width (CP);
   end Is_Zero_Width;

   function Is_Renderable_Attachment
     (CP : Common.Code_Point) return Boolean renames
       Character_Properties.Is_Renderable_Attachment;

   function Color_Graphics_ID
     (Value : Color;
      Valid : out Boolean) return Graphics_ID
   is
   begin
      case Value.Kind is
         when Default =>
            Valid := False;
            return 0;
         when Indexed =>
            Valid := True;
            return Graphics_ID (Value.Index);
         when RGB =>
            Valid := True;
            return
              Graphics_ID
                (Value.R * 16#1_0000# + Value.G * 16#100# + Value.B);
      end case;
   end Color_Graphics_ID;

   procedure Decode_Image_Cell
     (T          : in out Terminal;
      Cell_Index : Positive)
   is separate;

   procedure Clear_Wide_Overlap
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      New_Width : Cell_Width)
     renames Screen_Rows.Clear_Wide_Overlap;

   procedure Normalize_Wide_Row (T : in out Terminal; Row : Positive)
     renames Screen_Rows.Normalize_Wide_Row;

   procedure Shift_Row_Right
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive)
     renames Screen_Rows.Shift_Right;

   procedure Shift_Row_Left
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive)
     renames Screen_Rows.Shift_Left;

   procedure Erase_Characters
     (T     : in out Terminal;
      Row   : Positive;
      Col   : Positive;
      Count : Positive)
     renames Screen_Rows.Erase_Characters;

   procedure Insert_Blank_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive)
     renames Screen_Rows.Insert_Blank_Lines;

   procedure Delete_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive)
     renames Screen_Rows.Delete_Lines;

   procedure Put_Code_Point
     (T : in out Terminal; CP : Common.Code_Point) is separate;

   procedure Clear_CSI (T : in out Terminal) renames
     Parser_Primitives.Clear_CSI;

   function Param
     (T       : Terminal;
      N       : Positive;
      Default : Natural) return Natural
     renames Parser_Primitives.Param;

   function Param_Separator
     (T : Terminal;
      N : Positive) return Standard.Character
     renames Parser_Primitives.Param_Separator;

   procedure Append_DECRQSS_Start
     (T     : in out Terminal;
      Valid : Boolean)
   is
   begin
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_Char (T, 'P');
      Append_Response_Char (T, (if Valid then '1' else '0'));
      Append_Response_Char (T, '$');
      Append_Response_Char (T, 'r');
   end Append_DECRQSS_Start;

   procedure Append_DECRQSS_End (T : in out Terminal) is
   begin
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_Char (T, '\');
   end Append_DECRQSS_End;

   procedure Append_DECRQSS_Negative (T : in out Terminal) is
   begin
      Append_DECRQSS_Start (T, Valid => False);
      Append_DECRQSS_End (T);
   end Append_DECRQSS_Negative;

   procedure Append_SGR_Status (T : in out Terminal) is separate;

   function Finish_Tmux_Passthrough
     (T                  : in out Terminal;
      Overflowed         : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural) return Boolean is separate;

   procedure Handle_Sixel_DCS
     (T      : in out Terminal;
      Extent : Common.Sixel.Analysis) is separate;

   procedure Handle_DECRQSS (T : in out Terminal) is separate;

   procedure Finish_Ignored_String
     (T                  : in out Terminal;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural) is separate;

   procedure Queue_Device_Status_Report
     (T    : in out Terminal;
      Kind : Natural)
     renames Response_Queries.Queue_Device_Status_Report;

   procedure Queue_Device_Attributes
     (T : in out Terminal)
   is
   begin
      Begin_Response (T);
      if T.Parser.CSI_Private = ASCII.NUL
        and then T.Parser.CSI_Count <= 1
        and then Param (T, 1, 0) = 0
      then
         Append_Response_String (T, ASCII.ESC & "[?62;4;22c");
      elsif T.Parser.CSI_Private = '>'
        and then T.Parser.CSI_Count <= 1
        and then Param (T, 1, 0) = 0
      then
         Append_Response_String (T, ASCII.ESC & "[>0;1;0c");
      else
         Increment_Saturating (T.Diag.Unsupported_Sequence);
      end if;
      End_Response (T);
   end Queue_Device_Attributes;

   procedure Queue_Window_Operation_Report
     (T      : in out Terminal;
      Number : Natural)
     renames Response_Queries.Queue_Window_Operation_Report;

   function Mode_Report_State
     (T       : Terminal;
      Prefix  : Standard.Character;
      Number  : Natural)
      return Natural
     renames Response_Queries.Mode_Report_State;

   procedure Queue_Mode_Report (T : in out Terminal)
     renames Response_Queries.Queue_Mode_Report;

   procedure Move_Cursor
     (T   : in out Terminal;
      Row : Natural;
      Col : Natural)
   is
      Requested_Row : constant Positive := Positive'Max (1, Row);
      Requested_Col : constant Positive := Positive'Max (1, Col);
      Old_Row       : constant Positive := T.Cursor_Row;
   begin
      if T.Current_Modes.Origin_Mode then
         T.Cursor_Row :=
           Positive'Min
             (T.Bottom_Margin,
              T.Top_Margin + Positive'Min (Requested_Row, T.Bottom_Margin - T.Top_Margin + 1) - 1);
      else
         T.Cursor_Row := Positive'Min (T.Rows, Requested_Row);
      end if;
      T.Cursor_Col := Positive'Min (T.Cols, Requested_Col);
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Move_Cursor;

   function Next_Tab_Column (T : Terminal; Col : Positive) return Positive is
   begin
      if T.Tab_Stops /= null and then Col < T.Cols then
         for C in Col + 1 .. T.Cols loop
            if T.Tab_Stops (C) then
               return C;
            end if;
         end loop;
      end if;

      return T.Cols;
   end Next_Tab_Column;

   function Previous_Tab_Column (T : Terminal; Col : Positive) return Positive is
   begin
      if Col = 1 then
         return 1;
      end if;

      if T.Tab_Stops /= null then
         for C in reverse 1 .. Col - 1 loop
            if T.Tab_Stops (C) then
               return C;
            end if;
         end loop;
      end if;

      return 1;
   end Previous_Tab_Column;

   procedure Move_Forward_Tabs (T : in out Terminal; Count : Positive) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      for I in 1 .. Count loop
         T.Cursor_Col := Next_Tab_Column (T, T.Cursor_Col);
         exit when T.Cursor_Col = T.Cols;
      end loop;
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Move_Forward_Tabs;

   procedure Move_Backward_Tabs (T : in out Terminal; Count : Positive) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      for I in 1 .. Count loop
         T.Cursor_Col := Previous_Tab_Column (T, T.Cursor_Col);
         exit when T.Cursor_Col = 1;
      end loop;
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Move_Backward_Tabs;

   procedure Repeat_Last_Printable
     (T     : in out Terminal;
      Count : Positive)
   is separate;

   procedure Set_Mode (T : in out Terminal; Number : Natural; Enable : Boolean) is separate;

   procedure Apply_SGR (T : in out Terminal) is separate;

   procedure Soft_Reset (T : in out Terminal) is separate;

   --  The progressive keyboard enhancement controls: CSI > flags u pushes,
   --  CSI < n u pops n, CSI = flags ; mode u sets (1), adds (2), or removes
   --  (3) flags, and CSI ? u asks for the current ones.
   procedure Apply_Keyboard_Protocol (T : in out Terminal) is separate;

   --  XTVERSION: DCS > | name version ST.
   procedure Queue_Version_Report (T : in out Terminal) is
   begin
      if T.Parser.CSI_Count > 1 or else Param (T, 1, 0) /= 0 then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      end if;

      Begin_Response (T);
      Append_Response_String
        (T,
         ASCII.ESC & "P>|" & Common.Identity.Program_Name & " "
         & Common.Identity.Program_Version & ASCII.ESC & "\");
      End_Response (T);
   end Queue_Version_Report;

   procedure Queue_Resize_Report (T : in out Terminal) is
   begin
      Begin_Response (T);
      Append_Response_String (T, ASCII.ESC & "[48;");
      Append_Response_Natural (T, T.Rows);
      Append_Response_Char (T, ';');
      Append_Response_Natural (T, T.Cols);
      Append_Response_Char (T, ';');
      Append_Response_Natural (T, Natural'Min (T.Rows, Natural'Last / Positive'Max (1, T.Cell_Pixel_Height))
                                  * T.Cell_Pixel_Height);
      Append_Response_Char (T, ';');
      Append_Response_Natural (T, Natural'Min (T.Cols, Natural'Last / Positive'Max (1, T.Cell_Pixel_Width))
                                  * T.Cell_Pixel_Width);
      Append_Response_Char (T, 't');
      End_Response (T);
   end Queue_Resize_Report;

   procedure Refresh_Keyboard_Flags (T : in out Terminal) is
      Stack : Keyboard_Stack renames T.Keyboard_Stacks (T.Current_Modes.Alternate_Screen);
   begin
      T.Current_Modes.Keyboard_Flags := (if Stack.Depth = 0 then 0 else Stack.Flags (Stack.Depth));
   end Refresh_Keyboard_Flags;

   procedure Execute_CSI
     (T : in out Terminal; Final : Standard.Character)
     renames Parser_Execution.Execute_CSI;

   procedure Execute_C0 (T : in out Terminal; B : Common.Bytes.Byte) is
   begin
      case Natural (B) is
         when 7 =>
            Increment_Saturating (T.Notification_Data.Bell_Count);
            T.Notification_Data.Pending := True;
            T.Notification_Data.Kind := Terminal_Bell;
            T.Notification_Data.Title := (others => <>);
            T.Notification_Data.Message := (others => <>);
         when 8 =>
            if T.Cursor_Col > 1 then
               T.Cursor_Col := T.Cursor_Col - 1;
               Mark_Cursor_Move (T, T.Cursor_Row);
            end if;
            T.Pending_Wrap := False;
         when 9 =>
            Move_Forward_Tabs (T, 1);
         when 10 | 11 | 12 =>
            if T.Current_Modes.Linefeed_New_Line then
               T.Cursor_Col := 1;
            end if;
            New_Line (T);
         when 13 =>
            T.Cursor_Col := 1;
            Mark_Cursor_Move (T, T.Cursor_Row);
            T.Pending_Wrap := False;
         when 14 =>
            T.Active_Charset := G1;
            T.Pending_Wrap := False;
         when 15 =>
            T.Active_Charset := G0;
            T.Pending_Wrap := False;
         when 27 =>
            T.Parser.State := Escape;
         when others =>
            null;
      end case;
   end Execute_C0;

   procedure Emit_UTF8_Replacement (T : in out Terminal) is
   begin
      Increment_Saturating (T.Diag.Malformed_UTF8);
      Put_Code_Point (T, 16#FFFD#);
      T.Parser.UTF8_Need := 0;
      T.Parser.UTF8_Seen := 0;
      T.Parser.UTF8_Accum := 0;
      T.Parser.UTF8_Min := 0;
   end Emit_UTF8_Replacement;

   procedure Recover_Incomplete_UTF8 (T : in out Terminal) is
   begin
      if T.Parser.State = Ground and then T.Parser.UTF8_Need > 0 then
         Emit_UTF8_Replacement (T);
      end if;
   end Recover_Incomplete_UTF8;

   procedure Decode_Printable
     (T : in out Terminal; B : Common.Bytes.Byte)
     renames Parser_Execution.Decode_Printable;
   --  UTF-8 decoding and legacy character-set mapping form one parser
   --  transition and live in their own subunit.
   --
   --  The declaration remains here because Feed dispatches bytes to it.
   --
   --  See terminal-core-parser_execution-decode_printable.adb.

   function Append_Deferred_Input
     (T    : in out Terminal;
      Data : Core_Byte_Array) return Boolean
   is
      Appended : constant Boolean :=
        Graphics_Runtime.Append_Deferred_Input (T.Graphics, Data);
   begin
      if not Appended then
         Increment_Saturating (T.Diag.Queue_Overflow);
      end if;
      return Appended;
   end Append_Deferred_Input;

   procedure Dispatch_Parser_Byte
     (T                  : in out Terminal;
      B                  : Common.Bytes.Byte;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural)
     renames Parser_Execution.Dispatch_Parser_Byte;

   procedure Process_Feed_Byte
     (T                  : in out Terminal;
      B                  : Common.Bytes.Byte;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural)
     renames Parser_Execution.Process_Feed_Byte;

   procedure Drain_Tmux_Passthrough
     (T                  : in out Terminal;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean) is separate;

   procedure Feed
     (T      : in out Terminal;
      Data   : Core_Byte_Array;
      Status : out Feed_Status) is separate;

   procedure Resize
     (T      : in out Terminal;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Resize_Status) is separate;

   procedure Build_Snapshot
     (T : Terminal'Class;
      S : in out Render_Snapshot;
      Intern : not null access function
        (State : in out Hyperlink_Runtime_State;
         Value : Hyperlink) return Stored_Hyperlink_Access) is separate;

   procedure Snapshot
     (T : Terminal'Class;
      S : in out Render_Snapshot) is
   begin
      Build_Snapshot (T, S, Hyperlink_Store.Intern_Snapshot'Access);
   end Snapshot;

   function Snapshot (T : Terminal'Class) return Render_Snapshot is
   begin
      return S : Render_Snapshot do
         begin
            Snapshot (T, S);
         exception
            when others =>
               Release (S);
               raise;
         end;
      end return;
   end Snapshot;

   procedure Release (S : in out Render_Snapshot)
     renames Snapshot_Access.Release;

   function Cell_Count (S : Render_Snapshot) return Natural
     renames Snapshot_Access.Cell_Count;

   function Image_Cell_Count (S : Render_Snapshot) return Natural
     renames Snapshot_Access.Image_Cell_Count;

   function Blinking_Cell_Count (S : Render_Snapshot) return Natural
     renames Snapshot_Access.Blinking_Cell_Count;

   function Is_Valid (S : Render_Snapshot) return Boolean
     renames Snapshot_Access.Is_Valid;

   function Rows (S : Render_Snapshot) return Natural
     renames Snapshot_Access.Rows;
   function Cols (S : Render_Snapshot) return Natural
     renames Snapshot_Access.Cols;
   function Graphics_Stream
     (S : Render_Snapshot) return Graphics_Stream_ID
     renames Snapshot_Access.Graphics_Stream;
   function Graphics_Transaction
     (S : Render_Snapshot) return Graphics_Transaction_Generation
     renames Snapshot_Access.Graphics_Transaction;
   function Alternate_Screen (S : Render_Snapshot) return Boolean
     renames Snapshot_Access.Alternate_Screen;
   function Screen_Generation
     (S : Render_Snapshot) return Graphics_Screen_Generation
     renames Snapshot_Access.Screen_Generation;
   function Scrollback_Offset (S : Render_Snapshot) return Natural
     renames Snapshot_Access.Scrollback_Offset;
   function Scrollback_Rows (S : Render_Snapshot) return Natural
     renames Snapshot_Access.Scrollback_Rows;
   function Graphics_Scroll_Current
     (S : Render_Snapshot) return Graphics_Scroll_Sequence
     renames Snapshot_Access.Graphics_Scroll_Current;
   function Graphics_Scroll_Oldest
     (S : Render_Snapshot) return Graphics_Scroll_Sequence
     renames Snapshot_Access.Graphics_Scroll_Oldest;
   function Graphics_Scroll_Count (S : Render_Snapshot) return Natural
     renames Snapshot_Access.Graphics_Scroll_Count;
   function Cursor (S : Render_Snapshot) return Cursor_State
     renames Snapshot_Access.Cursor;
   function Graphics (S : Render_Snapshot) return Graphics_Event
     renames Snapshot_Access.Graphics;

   function Cell_At_Index
     (S : Render_Snapshot; Index : Positive) return Cell
     renames Snapshot_Access.Cell_At_Index;

   function Cell_Content_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell_Content
     renames Snapshot_Access.Cell_Content_At;

   function Cell_Link_Equals
     (S     : Render_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Value : Hyperlink) return Boolean
     renames Snapshot_Access.Cell_Link_Equals;

   function Cell_Kind_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell_Kind
     renames Snapshot_Access.Cell_Kind_At;

   function Cell_Text_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Text_Cluster
     renames Snapshot_Access.Cell_Text_At;

   function Cell_Style_At_Index
     (S : Render_Snapshot; Index : Positive) return Cell_Style
     renames Snapshot_Access.Cell_Style_At_Index;

   function Has_Dirty_Rows (S : Render_Snapshot) return Boolean
     renames Snapshot_Access.Has_Dirty_Rows;

   function Dirty_Row
     (S : Render_Snapshot; Row : Positive) return Boolean
     renames Snapshot_Access.Dirty_Row;

   function Has_Graphics_Scroll_Events
     (S : Render_Snapshot) return Boolean
     renames Snapshot_Access.Has_Graphics_Scroll_Events;

   function Graphics_Scroll_Event_At
     (S : Render_Snapshot; Index : Positive) return Graphics_Scroll_Event
     renames Snapshot_Access.Graphics_Scroll_Event_At;

   overriding procedure Finalize (S : in out Render_Snapshot) is
   begin
      Release (S);
   exception
      --  A finalizer must not replace an exception already propagating from a
      --  snapshot consumer. Release remains available for explicit diagnostics.
      when E : others =>
         Cleanup_Diagnostics.Note_Snapshot_Finalizer_Failure (E);
   end Finalize;

   function Snapshot_Finalizer_Diagnostics
     return Snapshot_Finalizer_Diagnostic
     renames Cleanup_Diagnostics.Snapshot_Finalizer_Diagnostics;

   function Snapshot_Finalizer_Failure_Count return Natural is
     (Snapshot_Finalizer_Diagnostics.Count);

   procedure Reset_Snapshot_Finalizer_Diagnostics
     renames Cleanup_Diagnostics.Reset_Snapshot_Finalizer_Diagnostics;

   procedure Set_Cell_Pixel_Size
     (T      : in out Terminal;
      Width  : Positive;
      Height : Positive)
   is
      Changed : constant Boolean := Width /= T.Cell_Pixel_Width or else Height /= T.Cell_Pixel_Height;
   begin
      T.Cell_Pixel_Width := Width;
      T.Cell_Pixel_Height := Height;

      --  The size in pixels changes with the font even when the grid does not.
      if Changed and then T.Initialized and then T.Current_Modes.In_Band_Resize then
         Queue_Resize_Report (T);
      end if;
   end Set_Cell_Pixel_Size;

   procedure Set_Window_Pixel_Size
     (T      : in out Terminal;
      Width  : Natural;
      Height : Natural)
   is
   begin
      T.Window_Pixel_Width := Width;
      T.Window_Pixel_Height := Height;
   end Set_Window_Pixel_Size;

   procedure Set_Graphics_Capabilities
     (T       : in out Terminal;
      Profile : Graphics_Capability_Profile) is
   begin
      T.Graphics.Capabilities := Profile;
   end Set_Graphics_Capabilities;

   procedure Set_Graphics_Stream_ID
     (T  : in out Terminal;
      ID : Graphics_Stream_ID) is
   begin
      T.Graphics.Stream := ID;
      Graphics_Runtime.Refresh_Last_Event (T.Graphics);
   end Set_Graphics_Stream_ID;

   procedure Set_Graphics_Resource_Limits
     (T      : in out Terminal;
      Limits : Graphics_Resource_Limits)
   is
      Was_Blocked : constant Boolean := T.Graphics.Input_Blocked;
      Result : Graphics_Runtime.Limit_Reconcile_Result;
   begin
      Graphics_Runtime.Apply_Limits (T.Graphics, Limits, Result);
      if Result.Kitty_Discarded then
         Graphics_Runtime.Advance_Graphics_Transaction (T.Graphics);
      end if;
      if Result.Transfer_Discarded then
         Common.Counters.Increment_Saturating (T.Diag.Parser_Overflow);
         if T.Parser.State = Ignored_String then
            T.Parser.State := Ignored_String_Overflow;
         elsif T.Parser.State = Ignored_String_Escape then
            T.Parser.State := Ignored_String_Overflow_Escape;
         end if;
      end if;
      if Result.Deferred_Discarded then
         Common.Counters.Increment_Saturating (T.Diag.Parser_Overflow);
      end if;
      if Result.Kitty_Discarded
        or else Result.Multipart_Discarded
        or else Result.Dropped_Events > 0
      then
         Common.Counters.Increment_Saturating (T.Diag.Queue_Overflow);
      end if;
      if Was_Blocked and then not T.Graphics.Input_Blocked then
         Graphics_Events.Resume_Deferred_Input (T);
      end if;
   end Set_Graphics_Resource_Limits;

   function Graphics_Resource_Limit
     (T : Terminal) return Graphics_Resource_Limits
     renames State_Access.Resource_Limit;

   function Modes (T : Terminal) return Mode_Snapshot
     renames State_Access.Modes;

   function Diagnostics (T : Terminal) return Diagnostic_Snapshot
     renames State_Access.Diagnostics;

   function Title (T : Terminal) return Title_Text
     renames State_Access.Title;

   function Shell_Integration
     (T : Terminal) return Shell_Integration_Snapshot is
     (T.Shell_State);

   function Shell_Mark_Count (T : Terminal) return Natural is
     (T.Shell_Mark_Total);

   function Shell_Mark_At (T : Terminal; Index : Positive) return Shell_Mark is
      Offset : Natural;
      Slot : Shell_Mark_Index;
   begin
      if Index > T.Shell_Mark_Total then
         raise Constraint_Error with "shell mark index out of range";
      end if;
      Offset := T.Shell_Mark_Total - Index;
      Slot := Shell_Mark_Index
        ((T.Shell_Mark_Head + Max_Shell_Marks - Offset - 1)
         mod Max_Shell_Marks + 1);
      return T.Shell_Marks (Slot);
   end Shell_Mark_At;

   function History_Rows_Produced (T : Terminal) return Natural is
     (T.History_Rows);

   function Shell_Command_Block_Count (T : Terminal) return Natural is
     (T.Shell_Command_Block_Total);

   function Shell_Command_Block_At
     (T : Terminal; Index : Positive) return Shell_Command_Block
   is
      Offset : Natural;
      Slot : Shell_Command_Block_Index;
   begin
      if Index > T.Shell_Command_Block_Total then
         raise Constraint_Error with "shell command block index out of range";
      end if;
      Offset := T.Shell_Command_Block_Total - Index;
      Slot := Shell_Command_Block_Index
        ((T.Shell_Command_Block_Head + Max_Shell_Command_Blocks - Offset - 1)
         mod Max_Shell_Command_Blocks + 1);
      return T.Shell_Command_Blocks (Slot);
   end Shell_Command_Block_At;

   function Terminal_Row_Count (T : Terminal) return Positive is (T.Rows);
   function Terminal_Column_Count (T : Terminal) return Positive is (T.Cols);

   function Absolute_Row_Available
     (T : Terminal; History_Row : Natural) return Boolean
   is
      Scroll_Rows : constant Natural := T.Scrollback_State.Rows;
      Oldest : constant Natural :=
        (if Scroll_Rows = 0 then
           (if T.History_Rows = Natural'Last
            then Natural'Last else T.History_Rows + 1)
         else T.History_Rows - Scroll_Rows + 1);
   begin
      return
        (History_Row >= Oldest and then History_Row <= T.History_Rows)
        or else
        (History_Row > T.History_Rows
         and then History_Row - T.History_Rows <= T.Rows);
   end Absolute_Row_Available;

   function Absolute_Cell_At
     (T           : Terminal;
      History_Row : Natural;
      Col         : Positive) return Cell
   is
      Scroll_Rows : constant Natural := T.Scrollback_State.Rows;
      Oldest : constant Natural :=
        (if Scroll_Rows = 0 then
           (if T.History_Rows = Natural'Last
            then Natural'Last else T.History_Rows + 1)
         else T.History_Rows - Scroll_Rows + 1);
   begin
      if Col > T.Cols or else not Absolute_Row_Available (T, History_Row) then
         return (Includes_Link => True, others => <>);
      elsif History_Row <= T.History_Rows then
         return Scrollback_Cell_At
           (T, Positive (History_Row - Oldest + 1), Col);
      else
         return Public_Cell
           (Active_Cells (T)
              (Index (T, Positive (History_Row - T.History_Rows), Col)));
      end if;
   end Absolute_Cell_At;

   function Notification (T : Terminal) return Notification_Request is
     (T.Notification_Data);

   procedure Clear_Notification (T : in out Terminal) is
   begin
      T.Notification_Data.Pending := False;
      T.Notification_Data.Title := (others => <>);
      T.Notification_Data.Message := (others => <>);
   end Clear_Notification;

   function Clipboard (T : Terminal) return Clipboard_Request
     renames State_Access.Clipboard;

   procedure Clear_Clipboard (T : in out Terminal)
     renames State_Access.Clear_Clipboard;

   function Scrollback_Row_Count (T : Terminal) return Natural
     renames State_Access.Scrollback_Row_Count;

   function Pending_Response_Length (T : Terminal) return Natural
     renames State_Access.Pending_Response_Length;

   function Pending_Graphics_Event_Count (T : Terminal) return Natural
     renames State_Access.Pending_Graphics_Event_Count;

   function Pending_Graphics_Byte_Count (T : Terminal) return Natural
     renames State_Access.Pending_Graphics_Byte_Count;

   procedure Peek_Graphics_Event
     (T     : Terminal;
      Event : out Graphics_Event)
     renames Graphics_Events.Peek;

   function Graphics_Event_Payload
     (T     : Terminal;
      Event : Graphics_Event) return String
     renames Graphics_Events.Payload;

   procedure Visit_Graphics_Event_Payload
     (T       : Terminal;
      Event   : Graphics_Event;
      Process : not null access procedure (Payload : String);
      Visited : out Boolean)
     renames Graphics_Events.Visit_Payload;

   procedure Discard_Graphics_Event (T : in out Terminal)
     renames Graphics_Events.Discard;

   function Take_Deferred_Feed_Status
     (T : in out Terminal) return Feed_Status
     renames Graphics_Events.Take_Deferred_Feed_Status;

   procedure Complete_Graphics_Event
     (T      : in out Terminal;
      Event  : Graphics_Event;
      Result : Graphics_Completion)
   is separate;

   procedure Read_Graphics_Event
     (T            : in out Terminal;
      Event        : out Graphics_Event;
      Buffer       : out Core_Byte_Array;
      Last         : out Natural;
      End_Of_Event : out Boolean)
     renames Graphics_Events.Read;

   procedure Read_Response
     (T      : in out Terminal;
      Buffer : out Common.Bytes.Byte_Array;
      Last   : out Natural)
     renames State_Access.Read_Response;

   procedure Clear_Damage (T : in out Terminal)
     renames State_Access.Clear_Damage;

   function Cell_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell
     renames Snapshot_Access.Cell_At;

   function Scrollback_Cell_At
     (T   : Terminal;
      Row : Positive;
      Col : Positive) return Cell
   is
   begin
      if T.Scrollback_State.Cells = null
        or else Row > T.Scrollback_State.Rows
        or else Col > T.Cols
      then
         return (Includes_Link => True, others => <>);
      end if;

      return Public_Cell
        (T.Scrollback_State.Cells
           (Scrollback_Storage.Index (T.Scrollback_State, T.Cols, Row, Col)));
   end Scrollback_Cell_At;
end Terminal.Core;
