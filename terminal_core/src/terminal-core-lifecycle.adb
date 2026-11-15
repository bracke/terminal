with Terminal.Core.Graphics_Runtime;
with Terminal.Core.Hyperlink_Store;
with Terminal.Core.Storage;

package body Terminal.Core.Lifecycle is
   use type Dirty_Row_Array_Access;
   use type Graphics_Scroll_Event_Array_Access;
   use type Stored_Cell_Array_Access;
   use type String_Access;
   use type Tab_Stop_Array_Access;

   procedure Finalize (T : in out Terminal) is
   begin
      Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
      Graphics_Runtime.Clear_ITerm2_Multipart (T.Graphics);
      Graphics_Runtime.Clear_Graphics_Events (T.Graphics);
      Graphics_Runtime.Clear_Deferred_Input (T.Graphics);
      T.Graphics.Queue_Overflowed := False;
      T.Graphics.Deferred_Feed_Status := Ok;
      T.Parser.Tmux_Passthrough_Depth := 0;
      if T.Parser.OSC_Data /= null then
         Storage.Release (T.Parser.OSC_Data);
      end if;
      T.Parser.OSC_Count := 0;
      T.Parser.OSC_Capacity := 0;
      if T.Primary_Cells /= null then
         Storage.Release (T.Primary_Cells);
      end if;
      if T.Alt_Cells /= null then
         Storage.Release (T.Alt_Cells);
      end if;
      if T.Scrollback_State.Cells /= null then
         Storage.Release (T.Scrollback_State.Cells);
      end if;
      T.Scrollback_State.Capacity_Rows := 0;
      if T.Dirty /= null then
         Storage.Release (T.Dirty);
      end if;
      if T.Tab_Stops /= null then
         Storage.Release (T.Tab_Stops);
      end if;
      if T.Graphics.Primary_Scroll_Events /= null then
         Storage.Release (T.Graphics.Primary_Scroll_Events);
      end if;
      if T.Graphics.Alternate_Scroll_Events /= null then
         Storage.Release (T.Graphics.Alternate_Scroll_Events);
      end if;
      Hyperlink_Store.Release_All (T.Hyperlinks);
      T.Initialized := False;
      T.Graphics.Last_Event := (others => <>);
   end Finalize;
end Terminal.Core.Lifecycle;
