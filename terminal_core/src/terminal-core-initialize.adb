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
   T.Scrollback_State.Rows := 0;
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
   T.Graphics.Last_Event := (others => <>);
   T.Graphics.Head := null;
   T.Graphics.Tail := null;
   T.Graphics.Event_Count := 0;
   T.Graphics.Blocking_Event_Count := 0;
   T.Graphics.Byte_Count := 0;
   T.Graphics.Stream := 0;
   T.Graphics.Primary_Generation := 0;
   T.Graphics.Alternate_Generation := 0;
   T.Graphics.Primary_Scroll_Events := null;
   T.Graphics.Alternate_Scroll_Events := null;
   Reset_Graphics_Scroll (T, False);
   Reset_Graphics_Scroll (T, True);
   T.Graphics.Next_Sequence := 1;
   T.Graphics.Transaction := 1;
   T.Graphics.Input_Blocked := False;
   T.Graphics.Queue_Backpressure := False;
   T.Graphics.Queue_Overflowed := False;
   T.Graphics.Deferred_Feed_Status := Ok;
   T.Graphics.Kitty_Chunk_Active := False;
   T.Graphics.Kitty_Chunk_Blocks_Input := False;
   T.Graphics.Kitty_Chunk_Action := 't';
   T.Graphics.Kitty_Chunk_Data := null;
   T.Graphics.Kitty_Chunk_Length := 0;
   T.Graphics.Kitty_Chunk_Capacity := 0;
   T.Graphics.Deferred_Input := null;
   T.Graphics.Deferred_Input_Length := 0;
   T.Graphics.Deferred_Input_Capacity := 0;
   T.Graphics.Transfer := null;
   T.Graphics.Transfer_Length := 0;
   T.Graphics.Transfer_Capacity := 0;
   T.Graphics.Limits := Default_Graphics_Resource_Limits;
   T.Graphics.ITerm2_Multipart := null;
   T.Graphics.ITerm2_Multipart_Length := 0;
   T.Graphics.ITerm2_Multipart_Capacity := 0;
   T.Graphics.ITerm2_Multipart_Active := False;
   T.Graphics.Capabilities := (others => False);
   T.Last_Printable := 0;
   T.Last_Printable_Text := (others => <>);
   T.Last_Printable_Clipped_Wide := False;
   T.Has_Last_Printable := False;
   T.Window_Title := (others => <>);
   T.Saved_Window_Title := (others => <>);
   T.Saved_Window_Title_Valid := False;
   T.Clipboard_Data := (others => <>);
   T.Progress_Data := (others => <>);
   T.Badge_Data := (others => <>);
   T.Hyperlinks.Current := null;
   T.Hyperlinks.Head := null;
   T.Hyperlinks.Index.Clear;
   T.Responses := (others => <>);
   T.Parser.State := Ground;
   T.Parser.CSI_Private := ASCII.NUL;
   T.Parser.CSI_Params := (others => 0);
   T.Parser.CSI_Set := (others => False);
   T.Parser.CSI_Separators := (others => ASCII.NUL);
   T.Parser.CSI_Count := 0;
   T.Parser.CSI_Intermediates := (others => ASCII.NUL);
   T.Parser.CSI_Intermediate_Count := 0;
   T.Parser.CSI_Invalid := False;
   T.Parser.OSC_Data := null;
   T.Parser.OSC_Count := 0;
   T.Parser.OSC_Capacity := 0;
   T.Parser.Ignored_String_Data := (others => ASCII.NUL);
   T.Parser.Ignored_String_Count := 0;
   T.Parser.Ignored_String_Is_DCS := False;
   T.Parser.Ignored_String_Is_APC := False;
   T.Parser.Tmux_Passthrough_Depth := 0;
   T.Parser.UTF8_Need := 0;
   T.Parser.UTF8_Seen := 0;
   T.Parser.UTF8_Accum := 0;
   T.Parser.UTF8_Min := 0;
   T.Scrollback_State.Limit := Scrollback_Limit;
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
