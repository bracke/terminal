separate (Terminal.Core)
procedure Initialize
  (T                : in out Terminal;
   Rows             : Positive;
   Cols             : Positive;
   Scrollback_Limit : Natural := 10_000;
   Status           : out Initialize_Status)
is
   Allocated : Boolean;
begin
   --  Initialize is intentionally repeatable.  Reclaim every allocation
   --  owned by an earlier initialization (including a partially failed
   --  one) before establishing the new state.
   Finalize (T);
   if Rows > Positive'Last / Cols then
      Status := Invalid_Size;
      return;
   elsif Scrollback_Limit > 0
     and then Scrollback_Limit > Natural'Last / Cols
   then
      Status := Invalid_Scrollback_Limit;
      return;
   end if;

   T.Initialized := False;
   T.Rows := Rows;
   T.Cols := Cols;
   T.Scrollback_Rows := 0;
   T.Active := Primary;
   T.Cursor_Row := 1;
   T.Cursor_Col := 1;
   T.Current_Cursor_Shape := Cursor_Block;
   T.Current_Cursor_Blinking := False;
   T.Saved_Row := 1;
   T.Saved_Col := 1;
   T.Pending_Wrap := False;
   T.Current_Style := (others => <>);
   T.Saved_Style := (others => <>);
   T.Current_Modes := (others => <>);
   T.G0_Charset := ASCII_Charset;
   T.G1_Charset := ASCII_Charset;
   T.G2_Charset := ASCII_Charset;
   T.G3_Charset := ASCII_Charset;
   T.Active_Charset := G0;
   T.Charset_Target := G0;
   T.Single_Shift_Charset := G2;
   T.Saved_G0_Charset := ASCII_Charset;
   T.Saved_G1_Charset := ASCII_Charset;
   T.Saved_G2_Charset := ASCII_Charset;
   T.Saved_G3_Charset := ASCII_Charset;
   T.Saved_Active_Charset := G0;
   T.Diag := (others => <>);
   T.Last_Graphics := (others => <>);
   T.Graphics_Head := null;
   T.Graphics_Tail := null;
   T.Graphics_Event_Count := 0;
   T.Graphics_Byte_Count := 0;
   T.Graphics_Stream := 0;
   T.Primary_Graphics_Generation := 0;
   T.Alternate_Graphics_Generation := 0;
   T.Primary_Graphics_Scroll_Events := null;
   T.Alternate_Graphics_Scroll_Events := null;
   Reset_Graphics_Scroll (T, False);
   Reset_Graphics_Scroll (T, True);
   T.Next_Graphics_Sequence := 1;
   T.Graphics_Transaction := 1;
   T.Graphics_Input_Blocked := False;
   T.Graphics_Queue_Backpressure := False;
   T.Kitty_Chunk_Active := False;
   T.Kitty_Chunk_Blocks_Input := False;
   T.Kitty_Chunk_Action := 't';
   T.Kitty_Chunk_Data := null;
   T.Kitty_Chunk_Length := 0;
   T.Kitty_Chunk_Capacity := 0;
   T.Deferred_Input := null;
   T.Deferred_Input_Length := 0;
   T.Deferred_Input_Capacity := 0;
   T.Graphics_Transfer := null;
   T.Graphics_Transfer_Length := 0;
   T.Graphics_Transfer_Capacity := 0;
   T.Graphics_Limits := Default_Graphics_Resource_Limits;
   T.ITerm2_Multipart := null;
   T.ITerm2_Multipart_Length := 0;
   T.ITerm2_Multipart_Capacity := 0;
   T.ITerm2_Multipart_Active := False;
   T.Graphics_Capabilities := (others => False);
   T.Last_Printable := 0;
   T.Has_Last_Printable := False;
   T.Window_Title := (others => <>);
   T.Saved_Window_Title := (others => <>);
   T.Saved_Window_Title_Valid := False;
   T.Clipboard_Data := (others => <>);
   T.Current_Link := (others => <>);
   T.Response_Length := 0;
   T.Response_Transaction_Start := 0;
   T.Response_Transaction_Active := False;
   T.Response_Transaction_Overflowed := False;
   T.State := Ground;
   T.CSI_Private := ASCII.NUL;
   T.CSI_Params := (others => 0);
   T.CSI_Set := (others => False);
   T.CSI_Separators := (others => ASCII.NUL);
   T.CSI_Count := 0;
   T.CSI_Intermediates := (others => ASCII.NUL);
   T.CSI_Intermediate_Count := 0;
   T.OSC_Data := null;
   T.OSC_Count := 0;
   T.OSC_Capacity := 0;
   T.Ignored_String_Data := (others => ASCII.NUL);
   T.Ignored_String_Count := 0;
   T.Ignored_String_Is_DCS := False;
   T.Ignored_String_Is_APC := False;
   T.UTF8_Need := 0;
   T.UTF8_Seen := 0;
   T.UTF8_Accum := 0;
   T.UTF8_Min := 0;
   T.Scrollback_Limit := Scrollback_Limit;
   Allocate_Buffers (T, Rows, Cols, Allocated);
   if not Allocated then
      Finalize (T);
      Status := Allocation_Failed;
      return;
   end if;

   T.Initialized := True;
   Reset_Terminal (T);
   Status := Ok;
end Initialize;
