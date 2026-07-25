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
      Italic     : Boolean := False;
      Underline  : Boolean := False;
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

   type Cursor_State is record
      Row     : Positive := 1;
      Col     : Positive := 1;
      Visible : Boolean := True;
   end record;

   type Mode_Snapshot is record
      Application_Cursor : Boolean := False;
      Bracketed_Paste    : Boolean := False;
      Alternate_Screen   : Boolean := False;
      Origin_Mode        : Boolean := False;
      Autowrap           : Boolean := True;
      Cursor_Visible     : Boolean := True;
      Insert_Mode        : Boolean := False;
   end record;

   type Diagnostic_Snapshot is record
      Malformed_UTF8       : Natural := 0;
      Ignored_Escape       : Natural := 0;
      Parser_Overflow      : Natural := 0;
      Queue_Overflow       : Natural := 0;
      Unsupported_Sequence : Natural := 0;
   end record;

   type Cell_Array is array (Positive range <>) of Cell;
   type Dirty_Row_Array is array (Positive range <>) of Boolean;
   subtype Core_Byte_Array is Terminal.Common.Bytes.Byte_Array;

   type Cell_Array_Access is access all Cell_Array;
   type Dirty_Row_Array_Access is access all Dirty_Row_Array;

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

   function Snapshot (T : Terminal) return Render_Snapshot;
   procedure Release (S : in out Render_Snapshot);
   function Modes (T : Terminal) return Mode_Snapshot;
   function Diagnostics (T : Terminal) return Diagnostic_Snapshot;
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
      Charset);
   subtype Param_Index is Positive range 1 .. 16;
   type Param_Array is array (Param_Index) of Natural;
   type Param_Set_Array is array (Param_Index) of Boolean;

   type Buffer_Kind is (Primary, Alternate);
   Max_Response_Length : constant := 128;
   subtype Response_Index is Positive range 1 .. Max_Response_Length;
   type Response_Buffer is
     array (Response_Index) of Common.Bytes.Byte;

   type Terminal is limited record
      Initialized      : Boolean := False;
      Rows             : Positive := 1;
      Cols             : Positive := 1;
      Scrollback_Limit : Natural := 10_000;
      Scrollback_Rows  : Natural := 0;

      Primary_Cells : Cell_Array_Access := null;
      Alt_Cells     : Cell_Array_Access := null;
      Scrollback    : Cell_Array_Access := null;
      Dirty         : Dirty_Row_Array_Access := null;

      Active        : Buffer_Kind := Primary;
      Cursor_Row    : Positive := 1;
      Cursor_Col    : Positive := 1;
      Saved_Row     : Positive := 1;
      Saved_Col     : Positive := 1;
      Pending_Wrap  : Boolean := False;
      Top_Margin    : Positive := 1;
      Bottom_Margin : Positive := 1;
      Current_Style : Style;
      Current_Modes : Mode_Snapshot;
      Diag          : Diagnostic_Snapshot;
      Responses     : Response_Buffer := (others => 0);
      Response_Length : Natural range 0 .. Max_Response_Length := 0;

      State         : Parser_State := Ground;
      CSI_Private   : Standard.Character := ASCII.NUL;
      CSI_Params    : Param_Array := (others => 0);
      CSI_Set       : Param_Set_Array := (others => False);
      CSI_Count     : Natural := 0;
      OSC_Count     : Natural := 0;

      UTF8_Need     : Natural := 0;
      UTF8_Seen     : Natural := 0;
      UTF8_Accum    : Common.Code_Point := 0;
      UTF8_Min      : Natural := 0;
   end record;
end Terminal.Core;
