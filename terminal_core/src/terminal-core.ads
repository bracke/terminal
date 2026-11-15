with Ada.Finalization;
with Ada.Containers.Ordered_Sets;
with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Common.Graphics_Limits;

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

   Max_Graphics_Scroll_Events : constant :=
     Terminal.Common.Graphics_Limits.Max_Scroll_Events;
   type Graphics_Scroll_Direction is (Graphics_Scroll_Up, Graphics_Scroll_Down);
   type Graphics_Scroll_Event is record
      Sequence  : Graphics_Scroll_Sequence := 0;
      Direction : Graphics_Scroll_Direction := Graphics_Scroll_Up;
      Top       : Positive := 1;
      Bottom    : Positive := 1;
      Count     : Positive := 1;
   end record;
   --  Configured by the embedding application. The core owns framing and
   --  immediate query replies, but must never infer backend capabilities.
   type Graphics_Capability_Profile is record
      Kitty_Direct_RGB         : Boolean := False;
      Kitty_Direct_RGBA        : Boolean := False;
      Kitty_Indexed_RGB        : Boolean := False;
      Kitty_Indexed_RGBA       : Boolean := False;
      Kitty_Direct_PNG         : Boolean := False;
      --  The private transmit formats f=1001 (JPEG) and f=1002 (GIF), which
      --  the identity answer advertises as kgfx-jpeg and kgfx-gif.
      Kitty_Direct_JPEG        : Boolean := False;
      Kitty_Direct_GIF         : Boolean := False;
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

   function Same_Hyperlink (Left, Right : Hyperlink) return Boolean;

   --  One constrained variant defines both public cell views.  This keeps the
   --  display fields structurally identical while allowing hot paths to use a
   --  link-free object whose representation excludes the bounded OSC 8 value.
   type Cell_Data (Includes_Link : Boolean) is record
      Kind  : Cell_Kind := Empty;
      Text  : Text_Cluster;
      Style : Cell_Style;
      Image : Image_Cell_Metadata;
      case Includes_Link is
         when True =>
            Link : Hyperlink;
         when False =>
            null;
      end case;
   end record;
   subtype Cell is Cell_Data (Includes_Link => True);
   subtype Cell_Content is Cell_Data (Includes_Link => False);

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

   type Graphics_Protocol_Kind is
     (No_Graphics,
      Sixel_Graphics,
      Kitty_Graphics,
      ITerm2_Graphics);

   Max_Graphics_Preview_Length : constant :=
     Terminal.Common.Graphics_Limits.Max_Core_Preview_Bytes;
   --  Compatibility snapshots retain only this bounded prefix.  Complete
   --  graphics commands are delivered through Read_Graphics_Event below.
   subtype Graphics_Preview_Length_Range is
     Natural range 0 .. Max_Graphics_Preview_Length;

   Max_Graphics_Transaction_Length : constant :=
     Terminal.Common.Graphics_Limits.Max_Transaction_Bytes;
   --  A conforming direct transfer may use thousands of 4096-byte APC
   --  chunks.  The byte quota is the primary memory bound; this separate
   --  count also bounds streams of payload-free commands.
   Max_Pending_Graphics_Events     : constant :=
     Terminal.Common.Graphics_Limits.Max_Pending_Events;
   Max_Pending_Graphics_Bytes      : constant :=
     Terminal.Common.Graphics_Limits.Max_Pending_Bytes;
   Max_Deferred_Input_Bytes        : constant :=
     Terminal.Common.Graphics_Limits.Max_Deferred_Input_Bytes;
   Max_Graphics_Pixel_Dimension    : constant :=
     Terminal.Common.Graphics_Limits.Max_Pixel_Dimension;

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
      Protocol       : Graphics_Protocol_Kind := No_Graphics;
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

   type Graphics_Completion_Code is
     (Graphics_No_Response,
      Graphics_OK,
      Graphics_EINVAL,
      Graphics_ENOENT,
      Graphics_ENOMEM,
      Graphics_ENOSPC,
      Graphics_EBADF,
      Graphics_ENOTSUP,
      Graphics_ENOPARENT,
      Graphics_ECYCLE,
      Graphics_ETOODEEP);

   type Graphics_Cursor_Completion is record
      Move               : Boolean := False;
      To_Line_Start      : Boolean := False;
      Placement_Columns  : Positive := 1;
      Placement_Rows     : Positive := 1;
   end record;

   type Kitty_Response_Metadata is record
      Present            : Boolean := False;
      Image_ID           : Graphics_ID := 0;
      Image_Number       : Graphics_ID := 0;
      Has_Image_Number   : Boolean := False;
      Placement_ID       : Graphics_ID := 0;
      Has_Placement_ID   : Boolean := False;
      Quiet              : Natural range 0 .. 2 := 0;
      Respond            : Boolean := True;
   end record;

   type Graphics_Completion is record
      Code               : Graphics_Completion_Code := Graphics_No_Response;
      Cursor             : Graphics_Cursor_Completion := (others => <>);
      Kitty_Response     : Kitty_Response_Metadata := (others => <>);
   end record;

   type Diagnostic_Snapshot is record
      Malformed_UTF8       : Natural := 0;
      Ignored_Escape       : Natural := 0;
      Parser_Overflow      : Natural := 0;
      Queue_Overflow       : Natural := 0;
      Unsupported_Sequence : Natural := 0;
      Text_Cluster_Overflow : Natural := 0;
      Graphics_Commands_Received : Natural := 0;
      Sixel_Commands_Received : Natural := 0;
      Kitty_Commands_Received : Natural := 0;
      ITerm2_Commands_Received : Natural := 0;
      Multiplexer_Passthrough : Natural := 0;
      Last_Graphics_Protocol  : Graphics_Protocol_Kind := No_Graphics;
      Last_Graphics_Payload_Length : Natural := 0;
   end record;

   Max_Status_Label_Length : constant := 96;

   Max_Title_Length : constant := 256;
   subtype Title_Length_Range is Natural range 0 .. Max_Title_Length;

   type Title_Text is record
      Length : Title_Length_Range := 0;
      Text   : String (1 .. Max_Title_Length) := (others => ' ');
   end record;

   Max_Working_Directory_Length : constant := 1_024;
   subtype Working_Directory_Length_Range is
     Natural range 0 .. Max_Working_Directory_Length;
   type Working_Directory_Text is record
      Length : Working_Directory_Length_Range := 0;
      Text   : String (1 .. Max_Working_Directory_Length) :=
        (others => ' ');
   end record;

   type Semantic_Zone is
     (No_Semantic_Zone,
      Prompt_Zone,
      Input_Zone,
      Output_Zone);

   type Shell_Integration_Snapshot is record
      Working_Directory : Working_Directory_Text;
      Zone              : Semantic_Zone := No_Semantic_Zone;
      Prompt_Count      : Natural := 0;
      Command_Count     : Natural := 0;
      Output_Count      : Natural := 0;
      Completion_Count  : Natural := 0;
      Last_Exit_Status  : Integer := 0;
      Has_Exit_Status   : Boolean := False;
   end record;

   type Shell_Mark_Kind is (Prompt_Mark, Command_Mark);
   type Shell_Mark is record
      Kind        : Shell_Mark_Kind := Prompt_Mark;
      History_Row : Natural := 0;
   end record;
   Max_Shell_Marks : constant := 128;

   type Shell_Command_Block is record
      Sequence              : Natural := 0;
      Prompt_Row            : Natural := 0;
      Prompt_Col            : Positive := 1;
      Input_Row             : Natural := 0;
      Input_Col             : Positive := 1;
      Output_Row            : Natural := 0;
      Output_Col            : Positive := 1;
      Completion_Row        : Natural := 0;
      Completion_Col        : Positive := 1;
      Has_Prompt            : Boolean := False;
      Has_Input             : Boolean := False;
      Has_Output            : Boolean := False;
      Complete              : Boolean := False;
      Has_Exit_Status       : Boolean := False;
      Exit_Status           : Integer := 0;
      Has_Duration          : Boolean := False;
      Duration_Milliseconds : Natural := 0;
   end record;
   Max_Shell_Command_Blocks : constant := 128;

   Max_Notification_Text_Length : constant := 512;
   subtype Notification_Text_Length is
     Natural range 0 .. Max_Notification_Text_Length;
   type Notification_Text is record
      Length : Notification_Text_Length := 0;
      Text   : String (1 .. Max_Notification_Text_Length) := (others => ' ');
   end record;
   type Notification_Kind is
     (Terminal_Bell, Desktop_Notification, Command_Completion);
   type Notification_Request is record
      Pending    : Boolean := False;
      Kind       : Notification_Kind := Terminal_Bell;
      Title      : Notification_Text;
      Message    : Notification_Text;
      Bell_Count : Natural := 0;
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

   subtype Core_Byte_Array is Terminal.Common.Bytes.Byte_Array;

   --  Backing arrays are encapsulated in one private storage component.
   --  Indexed accessors do not expose pointers into snapshot-owned storage.
   type Render_Snapshot_Storage is limited private;
   type Render_Snapshot is
     new Ada.Finalization.Limited_Controlled with private;

   overriding procedure Finalize (S : in out Render_Snapshot);

   --  Finalization cannot safely propagate cleanup exceptions.  This
   --  diagnostic keeps such failures attributable while explicit Release
   --  continues to report the original exception to its caller.
   Max_Snapshot_Cleanup_Detail_Length : constant := 64;
   subtype Snapshot_Cleanup_Detail_Length is
     Natural range 0 .. Max_Snapshot_Cleanup_Detail_Length;
   type Snapshot_Finalizer_Diagnostic is record
      Count : Natural := 0;
      Exception_Length : Snapshot_Cleanup_Detail_Length := 0;
      Exception_Name : String (1 .. Max_Snapshot_Cleanup_Detail_Length) :=
        (others => ' ');
   end record;
   function Snapshot_Finalizer_Diagnostics
     return Snapshot_Finalizer_Diagnostic;
   function Snapshot_Finalizer_Failure_Count return Natural;
   procedure Reset_Snapshot_Finalizer_Diagnostics;

   function Rows (S : Render_Snapshot) return Natural;
   function Cols (S : Render_Snapshot) return Natural;
   function Graphics_Stream
     (S : Render_Snapshot) return Graphics_Stream_ID;
   function Graphics_Transaction
     (S : Render_Snapshot) return Graphics_Transaction_Generation;
   function Alternate_Screen (S : Render_Snapshot) return Boolean;
   function Screen_Generation
     (S : Render_Snapshot) return Graphics_Screen_Generation;
   function Scrollback_Offset (S : Render_Snapshot) return Natural;
   function Scrollback_Rows (S : Render_Snapshot) return Natural;
   function Graphics_Scroll_Current
     (S : Render_Snapshot) return Graphics_Scroll_Sequence;
   function Graphics_Scroll_Oldest
     (S : Render_Snapshot) return Graphics_Scroll_Sequence;
   function Graphics_Scroll_Count (S : Render_Snapshot) return Natural;
   function Cursor (S : Render_Snapshot) return Cursor_State;
   --  The snapshot context describes the cells being presented.  A queued
   --  graphics event retains its own transaction and screen context because
   --  it may have been produced before an alternate-screen or transaction
   --  transition; renderers must apply the event using Graphics (S), not the
   --  presentation context accessors.
   function Graphics (S : Render_Snapshot) return Graphics_Event;
   function Is_Valid (S : Render_Snapshot) return Boolean;
   function Cell_Count (S : Render_Snapshot) return Natural;
   function Image_Cell_Count (S : Render_Snapshot) return Natural;
   function Blinking_Cell_Count (S : Render_Snapshot) return Natural;
   function Cell_At_Index
     (S : Render_Snapshot; Index : Positive) return Cell;
   function Cell_Content_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell_Content;
   function Cell_Link_Equals
     (S     : Render_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Value : Hyperlink) return Boolean;
   function Cell_Kind_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell_Kind;
   function Cell_Text_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Text_Cluster;
   function Cell_Style_At_Index
     (S : Render_Snapshot; Index : Positive) return Cell_Style;
   function Has_Dirty_Rows (S : Render_Snapshot) return Boolean;
   function Dirty_Row
     (S : Render_Snapshot; Row : Positive) return Boolean;
   function Has_Graphics_Scroll_Events
     (S : Render_Snapshot) return Boolean;
   function Graphics_Scroll_Event_At
     (S : Render_Snapshot; Index : Positive) return Graphics_Scroll_Event;

   --  The class-wide view is intentional: Limited_Controlled supplies
   --  deterministic cleanup, and terminal extensions retain the same screen
   --  semantics through the class-wide observer operations below.
   type Terminal is new Ada.Finalization.Limited_Controlled with private;

   function Shell_Mark_Count (T : Terminal) return Natural;
   function Shell_Mark_At (T : Terminal; Index : Positive) return Shell_Mark;
   function History_Rows_Produced (T : Terminal) return Natural;
   function Shell_Command_Block_Count (T : Terminal) return Natural;
   function Shell_Command_Block_At
     (T : Terminal; Index : Positive) return Shell_Command_Block;
   function Terminal_Row_Count (T : Terminal) return Positive;
   function Terminal_Column_Count (T : Terminal) return Positive;
   function Absolute_Row_Available
     (T : Terminal; History_Row : Natural) return Boolean;
   function Absolute_Cell_At
     (T           : Terminal;
      History_Row : Natural;
      Col         : Positive) return Cell;

   procedure Initialize
     (T                : in out Terminal;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural := 10_000;
      Status           : out Initialize_Status);

   overriding procedure Finalize (T : in out Terminal);

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

   function Snapshot (T : Terminal'Class) return Render_Snapshot;
   --  Refresh an existing snapshot, retaining its backing arrays when their
   --  dimensions still match.  This is the allocation-free path for steady
   --  state rendering.
   procedure Snapshot
     (T : Terminal'Class;
      S : in out Render_Snapshot);
   procedure Release (S : in out Render_Snapshot);
   function Modes (T : Terminal) return Mode_Snapshot;
   function Diagnostics (T : Terminal) return Diagnostic_Snapshot;
   function Title (T : Terminal) return Title_Text;
   function Shell_Integration
     (T : Terminal) return Shell_Integration_Snapshot;
   function Notification (T : Terminal) return Notification_Request;
   procedure Clear_Notification (T : in out Terminal);
   function Clipboard (T : Terminal) return Clipboard_Request;
   procedure Clear_Clipboard (T : in out Terminal);
   function Scrollback_Row_Count (T : Terminal) return Natural;
   function Pending_Response_Length (T : Terminal) return Natural;

   --  Complete graphics commands form a FIFO independent of the legacy
   --  preview in Render_Snapshot.  Read_Graphics_Event returns the event at
   --  the head and the next payload bytes.  End_Of_Event is true on the call
   --  that consumes the final payload bytes; the head remains pending until
   --  Complete_Graphics_Event or Discard_Graphics_Event acknowledges it.
   --  Event.Pending is false when the FIFO is empty.
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

   --  Borrow the current FIFO head's payload for the duration of Process.
   --  The callback must not retain a reference to Payload.  This avoids the
   --  full-size function result required by Graphics_Event_Payload when an
   --  embedding backend only needs to copy the bytes into owned staging.
   procedure Visit_Graphics_Event_Payload
     (T       : Terminal;
      Event   : Graphics_Event;
      Process : not null access procedure (Payload : String);
      Visited : out Boolean);

   procedure Discard_Graphics_Event (T : in out Terminal);

   --  Deferred input is parsed only after a blocking graphics command is
   --  retired.  Preserve the strongest status from that asynchronous parse so
   --  the embedding application can report it on its next poll.
   function Take_Deferred_Feed_Status
     (T : in out Terminal) return Feed_Status;

   --  Atomically queues the backend result for the current Kitty command and
   --  releases that FIFO head. A stale/mismatched event is left untouched.
   procedure Complete_Graphics_Event
     (T      : in out Terminal;
      Event  : Graphics_Event;
      Result : Graphics_Completion);

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
   --  Storage pointers are implementation details.  Keeping these access
   --  types private prevents clients from manufacturing aliases to snapshot
   --  or terminal-owned arrays.
   type Graphics_Scroll_Event_Array is
     array (Positive range <>) of Graphics_Scroll_Event;
   type Graphics_Scroll_Event_Array_Access is
     access all Graphics_Scroll_Event_Array;
   type Dirty_Row_Array is array (Positive range <>) of Boolean;
   type Tab_Stop_Array is array (Positive range <>) of Boolean;
   type Dirty_Row_Array_Access is access all Dirty_Row_Array;
   type Tab_Stop_Array_Access is access all Tab_Stop_Array;

   type Stored_Hyperlink;
   type Stored_Hyperlink_Access is access Stored_Hyperlink;
   type Stored_Hyperlink is record
      Value : Hyperlink;
      Next  : Stored_Hyperlink_Access := null;
      Previous : Stored_Hyperlink_Access := null;
      Marked : Boolean := False;
      Snapshot_References : Natural := 0;
   end record;
   function Stored_Hyperlink_Less
     (Left, Right : Stored_Hyperlink_Access) return Boolean;
   package Stored_Hyperlink_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => Stored_Hyperlink_Access,
      "<"          => Stored_Hyperlink_Less);

   --  Snapshots own a separate intern pool.  Keeping only a pointer in each
   --  cell avoids embedding the bounded 640-byte public Hyperlink value in
   --  every cell while still allowing a snapshot to outlive its terminal.
   type Snapshot_Cell is record
      Kind  : Cell_Kind := Empty;
      Text  : Text_Cluster;
      Style : Cell_Style;
      Link  : Stored_Hyperlink_Access := null;
      Image : Image_Cell_Metadata;
   end record;
   type Snapshot_Cell_Array is array (Positive range <>) of Snapshot_Cell;
   type Snapshot_Cell_Array_Access is access all Snapshot_Cell_Array;
   type Snapshot_Link_Array is
     array (Positive range <>) of Stored_Hyperlink_Access;
   type Snapshot_Link_Array_Access is access all Snapshot_Link_Array;

   type Hyperlink_Runtime_State is record
      Current    : Stored_Hyperlink_Access := null;
      Head       : Stored_Hyperlink_Access := null;
      --  Reusable lookup key for the pointer-keyed ordered set. It is never
      --  inserted, so changing its value cannot invalidate set ordering.
      Lookup     : Stored_Hyperlink_Access := null;
      Index      : Stored_Hyperlink_Sets.Set;
      Count      : Natural := 0;
      Next_Sweep : Natural := 1_024;
   end record;

   procedure Build_Snapshot
     (T      : Terminal'Class;
      S      : in out Render_Snapshot;
      Intern : not null access function
        (State : in out Hyperlink_Runtime_State;
         Value : Hyperlink) return Stored_Hyperlink_Access);

   --  Screen and scrollback storage use a compact hyperlink reference.  The
   --  public Cell value remains self-contained, so snapshots can safely
   --  outlive the terminal that produced them.
   type Stored_Cell is record
      Kind  : Cell_Kind := Empty;
      Text  : Text_Cluster;
      Style : Cell_Style;
      Link  : Stored_Hyperlink_Access := null;
      Image : Image_Cell_Metadata;
      --  A double-width scalar written while the grid has only one column is
      --  presented as a clipped single cell, but its semantic width must be
      --  retained so a later resize can restore the continuation cell.
      Clipped_Wide : Boolean := False;
      --  Meaningful only on the final physical cell of a row.  It records
      --  that output continued by autowrap, allowing resize to reconstruct
      --  logical lines instead of treating every grid row as a hard break.
      Wraps_To_Next : Boolean := False;
   end record;
   type Stored_Cell_Array is array (Positive range <>) of Stored_Cell;
   type Stored_Cell_Array_Access is access all Stored_Cell_Array;

   type Scrollback_Runtime_State is record
      Limit         : Natural := 10_000;
      Rows          : Natural := 0;
      --  Physical index (0-based) of the oldest row in the ring.
      Head          : Natural := 0;
      Cells         : Stored_Cell_Array_Access := null;
      Capacity_Rows : Natural := 0;
   end record;

   subtype Shell_Mark_Index is Positive range 1 .. Max_Shell_Marks;
   type Shell_Mark_Array is array (Shell_Mark_Index) of Shell_Mark;
   subtype Shell_Command_Block_Index is
     Positive range 1 .. Max_Shell_Command_Blocks;
   type Shell_Command_Block_Array is
     array (Shell_Command_Block_Index) of Shell_Command_Block;

   type Render_Snapshot_Storage is limited record
      Scroll_Events : Graphics_Scroll_Event_Array_Access := null;
      Cells_Data    : Snapshot_Cell_Array_Access := null;
      Batch_Cells   : Snapshot_Cell_Array_Access := null;
      Dirty_Data    : Dirty_Row_Array_Access := null;
      Prepared_Links : Snapshot_Link_Array_Access := null;
      Hyperlinks    : Hyperlink_Runtime_State;
      Image_Cells   : Natural := 0;
      Blinking_Cells : Natural := 0;
      Dirty_Rows    : Natural := 0;
      Wide_Violations : Natural := 0;
   end record;

   type Render_Snapshot is
     new Ada.Finalization.Limited_Controlled with record
      Storage : Render_Snapshot_Storage;
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
      Cursor : Cursor_State;
      Graphics : Graphics_Event;
   end record;

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
   type Response_Runtime_State is record
      Bytes                  : Response_Buffer := (others => 0);
      Length                 : Natural range 0 .. Max_Response_Length := 0;
      Transaction_Start      : Natural range 0 .. Max_Response_Length := 0;
      Transaction_Active     : Boolean := False;
      Transaction_Overflowed : Boolean := False;
   end record;
   Max_OSC_Payload_Length : constant Positive :=
     Common.Graphics_Limits.Max_OSC_Bytes;
   Max_Ignored_String_Preview_Length : constant Positive :=
     Common.Graphics_Limits.Max_Escape_Preview_Bytes;
   subtype Ignored_String_Index is
     Positive range 1 .. Max_Ignored_String_Preview_Length;
   type Ignored_String_Buffer is
     array (Ignored_String_Index) of Standard.Character;

   type String_Access is access all String;
   type Core_Byte_Array_Access is access all Core_Byte_Array;
   type Graphics_Event_Node;
   type Graphics_Event_Node_Access is access Graphics_Event_Node;
   type Graphics_Event_Node is record
      Protocol       : Graphics_Protocol_Kind := No_Graphics;
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

   type Graphics_Runtime_State is record
      Last_Event : Graphics_Event;
      Head : Graphics_Event_Node_Access := null;
      Tail : Graphics_Event_Node_Access := null;
      Event_Count : Natural range 0 .. Max_Pending_Graphics_Events := 0;
      Blocking_Event_Count : Natural range 0 .. Max_Pending_Graphics_Events := 0;
      Byte_Count  : Natural range 0 .. Max_Pending_Graphics_Bytes := 0;
      Stream      : Graphics_Stream_ID := 0;
      Primary_Generation : Graphics_Screen_Generation := 0;
      Alternate_Generation : Graphics_Screen_Generation := 0;
      Primary_Scroll_Sequence : Graphics_Scroll_Sequence := 0;
      Alternate_Scroll_Sequence : Graphics_Scroll_Sequence := 0;
      Primary_Scroll_Head : Natural range 0 .. Max_Graphics_Scroll_Events - 1 := 0;
      Alternate_Scroll_Head : Natural range 0 .. Max_Graphics_Scroll_Events - 1 := 0;
      Primary_Scroll_Count : Natural range 0 .. Max_Graphics_Scroll_Events := 0;
      Alternate_Scroll_Count : Natural range 0 .. Max_Graphics_Scroll_Events := 0;
      Primary_Scroll_Events : Graphics_Scroll_Event_Array_Access := null;
      Alternate_Scroll_Events : Graphics_Scroll_Event_Array_Access := null;
      Next_Sequence : Graphics_Event_Sequence := 1;
      Transaction : Graphics_Transaction_Generation := 1;
      Input_Blocked : Boolean := False;
      Queue_Backpressure : Boolean := False;
      Queue_Overflowed : Boolean := False;
      Deferred_Feed_Status : Feed_Status := Ok;
      Kitty_Chunk_Active : Boolean := False;
      Kitty_Chunk_Blocks_Input : Boolean := False;
      Kitty_Chunk_Action : Standard.Character := 't';
      Kitty_Chunk_Data : String_Access := null;
      Kitty_Chunk_Length : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      Kitty_Chunk_Capacity : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      Deferred_Input : Core_Byte_Array_Access := null;
      Deferred_Input_Length : Natural range 0 .. Max_Deferred_Input_Bytes := 0;
      Deferred_Input_Capacity : Natural range 0 .. Max_Deferred_Input_Bytes := 0;
      Transfer : String_Access := null;
      Limits : Graphics_Resource_Limits := Default_Graphics_Resource_Limits;
      Transfer_Length : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      Transfer_Capacity : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      ITerm2_Multipart : String_Access := null;
      ITerm2_Multipart_Length : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      ITerm2_Multipart_Capacity : Natural range 0 .. Max_Graphics_Transaction_Length := 0;
      ITerm2_Multipart_Active : Boolean := False;
      Capabilities : Graphics_Capability_Profile := (others => False);
   end record;

   Max_Tmux_Passthrough_Depth : constant := 16;

   type Parser_Runtime_State is record
      State : Parser_State := Ground;
      CSI_Private : Standard.Character := ASCII.NUL;
      CSI_Params : Param_Array := (others => 0);
      CSI_Set : Param_Set_Array := (others => False);
      CSI_Separators : Param_Separator_Array := (others => ASCII.NUL);
      CSI_Count : Natural := 0;
      CSI_Intermediates : CSI_Intermediate_Array := (others => ASCII.NUL);
      CSI_Intermediate_Count : Natural := 0;
      --  A CSI whose bounded representation overflowed must not be executed
      --  from the truncated or saturated values.  This state is part of the
      --  parser, rather than Feed's status accumulator, so recovery is
      --  independent of PTY read boundaries.
      CSI_Invalid : Boolean := False;
      OSC_Data : String_Access := null;
      OSC_Count : Natural := 0;
      OSC_Capacity : Natural range 0 .. Max_OSC_Payload_Length := 0;
      Ignored_String_Data : Ignored_String_Buffer := (others => ASCII.NUL);
      Ignored_String_Count : Natural := 0;
      Ignored_String_Is_DCS : Boolean := False;
      Ignored_String_Is_APC : Boolean := False;
      Tmux_Passthrough_Depth : Natural range
        0 .. Max_Tmux_Passthrough_Depth := 0;
      UTF8_Need : Natural := 0;
      UTF8_Seen : Natural := 0;
      UTF8_Accum : Natural := 0;
      UTF8_Min : Natural := 0;
   end record;

   type Terminal is new Ada.Finalization.Limited_Controlled with record
      Initialized      : Boolean := False;
      Rows             : Positive := 1;
      Cols             : Positive := 1;
      Cell_Pixel_Width : Natural := 0;
      Cell_Pixel_Height : Natural := 0;
      Window_Pixel_Width : Natural := 0;
      Window_Pixel_Height : Natural := 0;
      Scrollback_State : Scrollback_Runtime_State;

      Primary_Cells : Stored_Cell_Array_Access := null;
      Alt_Cells     : Stored_Cell_Array_Access := null;
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
      Graphics : Graphics_Runtime_State;
      Last_Printable : Common.Code_Point := 0;
      Last_Printable_Text : Text_Cluster := (others => <>);
      Last_Printable_Clipped_Wide : Boolean := False;
      Has_Last_Printable : Boolean := False;
      Window_Title  : Title_Text;
      Saved_Window_Title : Title_Text;
      Saved_Window_Title_Valid : Boolean := False;
      Shell_State : Shell_Integration_Snapshot;
      Shell_Marks : Shell_Mark_Array := (others => <>);
      Shell_Mark_Head : Natural range 0 .. Max_Shell_Marks - 1 := 0;
      Shell_Mark_Total : Natural range 0 .. Max_Shell_Marks := 0;
      Shell_Command_Blocks : Shell_Command_Block_Array := (others => <>);
      Shell_Command_Block_Head :
        Natural range 0 .. Max_Shell_Command_Blocks - 1 := 0;
      Shell_Command_Block_Total :
        Natural range 0 .. Max_Shell_Command_Blocks := 0;
      Current_Shell_Command_Block :
        Natural range 0 .. Max_Shell_Command_Blocks := 0;
      Next_Shell_Command_Sequence : Natural := 1;
      History_Rows : Natural := 0;
      Notification_Data : Notification_Request;
      Clipboard_Data : Clipboard_Request;
      Hyperlinks    : Hyperlink_Runtime_State;
      Responses     : Response_Runtime_State;

      Parser : Parser_Runtime_State;
   end record;

   --  Explicit action surface used by the parser engine. Parser_Execution is
   --  a private child, so it cannot depend on declarations hidden inside the
   --  parent body; every state-changing action it may invoke is listed here.
   procedure Enqueue_Graphics_Event
     (T              : in out Terminal;
      Protocol       : Graphics_Protocol_Kind;
      Row            : Positive;
      Col            : Positive;
      Payload        : String;
      Cancelled      : Boolean := False);
   procedure Reject_Kitty_Chunk_Interleave (T : in out Terminal);
   procedure Scroll_Up_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1);
   procedure Scroll_Down_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1);
   procedure Put_Code_Point
     (T : in out Terminal;
      CP : Common.Code_Point);
   procedure Finish_OSC (T : in out Terminal);
   procedure Finish_Ignored_String
     (T                  : in out Terminal;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural);
   procedure Queue_Device_Attributes (T : in out Terminal);
   procedure Move_Cursor
     (T   : in out Terminal;
      Row : Natural;
      Col : Natural);
   procedure Move_Forward_Tabs
     (T : in out Terminal;
      Count : Positive);
   procedure Move_Backward_Tabs
     (T : in out Terminal;
      Count : Positive);
   procedure Repeat_Last_Printable
     (T : in out Terminal;
      Count : Positive);
   procedure Set_Mode
     (T : in out Terminal;
      Number : Natural;
      Enable : Boolean);
   procedure Apply_SGR (T : in out Terminal);
   procedure Soft_Reset (T : in out Terminal);
   procedure Apply_Keyboard_Protocol (T : in out Terminal);
   procedure Queue_Version_Report (T : in out Terminal);
   procedure Index_Control (T : in out Terminal);
   procedure Next_Line_Control (T : in out Terminal);
   procedure Reverse_Index_Control (T : in out Terminal);
   procedure Reset_Terminal (T : in out Terminal);
   procedure Execute_C0
     (T : in out Terminal;
      B : Common.Bytes.Byte);
   procedure Emit_UTF8_Replacement (T : in out Terminal);
   procedure Recover_Incomplete_UTF8 (T : in out Terminal);

end Terminal.Core;
