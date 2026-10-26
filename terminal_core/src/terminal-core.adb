with Ada.Unchecked_Deallocation;
with Terminal.Common.Identity;
with Terminal.Core.Parser;

package body Terminal.Core is
   use Common;
   use Common.Bytes;

   procedure Free_Cells is new Ada.Unchecked_Deallocation
     (Cell_Array, Cell_Array_Access);
   procedure Free_Dirty is new Ada.Unchecked_Deallocation
     (Dirty_Row_Array, Dirty_Row_Array_Access);
   procedure Free_Graphics_Scroll_Events is new Ada.Unchecked_Deallocation
     (Graphics_Scroll_Event_Array, Graphics_Scroll_Event_Array_Access);
   procedure Free_Tab_Stops is new Ada.Unchecked_Deallocation
     (Tab_Stop_Array, Tab_Stop_Array_Access);
   procedure Free_String is new Ada.Unchecked_Deallocation
     (String, String_Access);
   procedure Free_Graphics_Node is new Ada.Unchecked_Deallocation
     (Graphics_Event_Node, Graphics_Event_Node_Access);
   procedure Free_Deferred_Input is new Ada.Unchecked_Deallocation
     (Core_Byte_Array, Core_Byte_Array_Access);

   procedure Clear_Deferred_Input (T : in out Terminal) is
   begin
      if T.Deferred_Input /= null then
         Free_Deferred_Input (T.Deferred_Input);
      end if;
      T.Deferred_Input := null;
      T.Deferred_Input_Length := 0;
      T.Deferred_Input_Capacity := 0;
   end Clear_Deferred_Input;

   procedure Clear_Graphics_Transfer (T : in out Terminal) is
   begin
      if T.Graphics_Transfer /= null then
         Free_String (T.Graphics_Transfer);
      end if;
      T.Graphics_Transfer := null;
      T.Graphics_Transfer_Length := 0;
      T.Graphics_Transfer_Capacity := 0;
   end Clear_Graphics_Transfer;

   procedure Clear_Kitty_Chunk (T : in out Terminal) is
   begin
      if T.Kitty_Chunk_Data /= null then
         Free_String (T.Kitty_Chunk_Data);
      end if;
      T.Kitty_Chunk_Data := null;
      T.Kitty_Chunk_Length := 0;
      T.Kitty_Chunk_Capacity := 0;
      T.Kitty_Chunk_Active := False;
      T.Kitty_Chunk_Blocks_Input := False;
      T.Kitty_Chunk_Action := 't';
   end Clear_Kitty_Chunk;

   procedure Advance_Graphics_Transaction (T : in out Terminal) is
   begin
      T.Graphics_Transaction := T.Graphics_Transaction + 1;
      if T.Graphics_Transaction = 0 then
         T.Graphics_Transaction := 1;
      end if;
   end Advance_Graphics_Transaction;

   procedure Clear_ITerm2_Multipart (T : in out Terminal) is
   begin
      if T.ITerm2_Multipart /= null then
         Free_String (T.ITerm2_Multipart);
      end if;
      T.ITerm2_Multipart := null;
      T.ITerm2_Multipart_Length := 0;
      T.ITerm2_Multipart_Capacity := 0;
      T.ITerm2_Multipart_Active := False;
   end Clear_ITerm2_Multipart;

   function Append_ITerm2_Multipart
     (T    : in out Terminal;
      Text : String) return Boolean
   is
      Required : Natural := 0;
      New_Capacity : Natural := 0;
      Replacement : String_Access := null;
   begin
      if Text'Length = 0 then
         return True;
      elsif Text'Length > T.Graphics_Limits.Transaction_Length
        or else T.ITerm2_Multipart_Length >
          T.Graphics_Limits.Transaction_Length - Text'Length
      then
         Clear_ITerm2_Multipart (T);
         return False;
      end if;
      Required := T.ITerm2_Multipart_Length + Text'Length;
      if Required > T.ITerm2_Multipart_Capacity then
         New_Capacity := Natural'Min
           (T.Graphics_Limits.Transaction_Length,
            Natural'Max (4_096, T.ITerm2_Multipart_Capacity));
         while New_Capacity < Required loop
            if New_Capacity > T.Graphics_Limits.Transaction_Length / 2 then
               New_Capacity := T.Graphics_Limits.Transaction_Length;
            else
               New_Capacity := New_Capacity * 2;
            end if;
         end loop;
         Replacement := new String (1 .. New_Capacity);
         if T.ITerm2_Multipart_Length > 0 then
            Replacement (1 .. T.ITerm2_Multipart_Length) :=
              T.ITerm2_Multipart (1 .. T.ITerm2_Multipart_Length);
         end if;
         if T.ITerm2_Multipart /= null then
            Free_String (T.ITerm2_Multipart);
         end if;
         T.ITerm2_Multipart := Replacement;
         T.ITerm2_Multipart_Capacity := New_Capacity;
         Replacement := null;
      end if;
      T.ITerm2_Multipart
        (T.ITerm2_Multipart_Length + 1 .. Required) := Text;
      T.ITerm2_Multipart_Length := Required;
      return True;
   exception
      when Storage_Error =>
         if Replacement /= null then
            Free_String (Replacement);
         end if;
         Clear_ITerm2_Multipart (T);
         return False;
   end Append_ITerm2_Multipart;

   procedure Clear_Graphics_Events (T : in out Terminal) is
      Current : Graphics_Event_Node_Access := T.Graphics_Head;
      Next    : Graphics_Event_Node_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         if Current.Payload /= null then
            Free_String (Current.Payload);
         end if;
         Free_Graphics_Node (Current);
         Current := Next;
      end loop;
      T.Graphics_Head := null;
      T.Graphics_Tail := null;
      T.Graphics_Event_Count := 0;
      T.Graphics_Byte_Count := 0;
      T.Graphics_Input_Blocked := False;
      T.Graphics_Queue_Backpressure := False;
      T.Graphics_Queue_Overflowed := False;
      Clear_Kitty_Chunk (T);
   end Clear_Graphics_Events;

   function Kitty_Field_Value
     (Payload : String;
      Key     : Standard.Character) return String
   is
      Header_Last : Natural := Payload'Last;
      Field_First : Natural := Payload'First;
      I : Natural;
   begin
      for Pos in Payload'Range loop
         if Payload (Pos) = ';' then
            Header_Last := Pos - 1;
            exit;
         end if;
      end loop;
      if Header_Last < Payload'First then
         return "";
      end if;

      I := Payload'First;
      if Payload (I) = 'G' then
         I := I + 1;
      end if;
      Field_First := I;
      while I <= Header_Last + 1 loop
         if I = Header_Last + 1 or else Payload (I) = ',' then
            if I >= Field_First + 2
              and then Payload (Field_First) = Key
              and then Payload (Field_First + 1) = '='
            then
               return Payload (Field_First + 2 .. I - 1);
            end if;
            Field_First := I + 1;
         end if;
         I := I + 1;
      end loop;
      return "";
   end Kitty_Field_Value;

   function Kitty_Command_Blocks_Input
     (T       : in out Terminal;
      Payload : String) return Boolean
   is
      Action_Text : constant String := Kitty_Field_Value (Payload, 'a');
      More_Text   : constant String := Kitty_Field_Value (Payload, 'm');
      Quiet_Text  : constant String := Kitty_Field_Value (Payload, 'q');
      Cursor_Text : constant String := Kitty_Field_Value (Payload, 'C');
      Virtual_Text : constant String := Kitty_Field_Value (Payload, 'U');
      Parent_Text : constant String := Kitty_Field_Value (Payload, 'P');
      Action : constant Standard.Character :=
        (if Action_Text'Length = 0 then 't' else Action_Text (Action_Text'First));
      Placement_Would_Move : constant Boolean :=
        Action in 'T' | 'p'
        and then Cursor_Text /= "1"
        and then Virtual_Text /= "1"
        and then (Parent_Text'Length = 0 or else Parent_Text = "0");
      Could_Respond : constant Boolean := Quiet_Text /= "2";
   begin
      if More_Text = "1" then
         return False;
      elsif More_Text = "0" then
         return
           (if T.Kitty_Chunk_Active
            then T.Kitty_Chunk_Blocks_Input
            else Could_Respond or else Placement_Would_Move);
      end if;
      --  The app produces both success and error replies after decoding and
      --  transport validation.  Serialize every command which may reply so a
      --  later synchronous terminal reply cannot overtake it.  q=2 commands
      --  need a barrier only when their placement also moves the cursor.
      return Could_Respond or else Placement_Would_Move;
   end Kitty_Command_Blocks_Input;

   function ITerm2_Command_Blocks_Input (Payload : String) return Boolean is
      function Has_Field (Field : String) return Boolean is
         First : Natural := Payload'First + 5;
         Last  : Natural;
      begin
         if Payload'Length < 5
           or else Payload (Payload'First .. Payload'First + 4) /= "File="
         then
            return False;
         end if;

         while First <= Payload'Last loop
            Last := First;
            while Last <= Payload'Last
              and then Payload (Last) not in ';' | ':'
            loop
               Last := Last + 1;
            end loop;
            if Last - First = Field'Length
              and then Payload (First .. Last - 1) = Field
            then
               return True;
            end if;
            exit when Last > Payload'Last or else Payload (Last) = ':';
            First := Last + 1;
         end loop;
         return False;
      end Has_Field;
   begin
      --  Inline images normally move the cursor below their rendered pixel
      --  height.  That height is known only after bounded decode and sizing
      --  in the app, so preserve input ordering until presentation commits.
      return Has_Field ("inline=1")
        and then not Has_Field ("doNotMoveCursor=1");
   end ITerm2_Command_Blocks_Input;

   procedure Drop_Graphics_Head (T : in out Terminal) is
      Node : Graphics_Event_Node_Access := T.Graphics_Head;
   begin
      if Node = null then
         return;
      end if;

      T.Graphics_Head := Node.Next;
      if T.Graphics_Head = null then
         T.Graphics_Tail := null;
      end if;
      T.Graphics_Event_Count := T.Graphics_Event_Count - 1;
      T.Graphics_Byte_Count := T.Graphics_Byte_Count - Node.Payload_Length;
      if Node.Payload /= null then
         Free_String (Node.Payload);
      end if;
      Free_Graphics_Node (Node);
   end Drop_Graphics_Head;

   procedure Refresh_Graphics_Input_Block (T : in out Terminal) is
      Current : Graphics_Event_Node_Access := T.Graphics_Head;
      Has_Semantic_Barrier : Boolean := False;
   begin
      T.Graphics_Queue_Backpressure :=
        T.Graphics_Event_Count >= T.Graphics_Limits.Pending_Events
        or else
          (T.Graphics_Event_Count > 0
           and then
             (T.Graphics_Byte_Count >= T.Graphics_Limits.Pending_Bytes
              or else
                T.Graphics_Limits.Pending_Bytes - T.Graphics_Byte_Count <
                  Natural'Min
                    (T.Graphics_Limits.Transaction_Length,
                     T.Graphics_Limits.Pending_Bytes)));
      while Current /= null and then not Has_Semantic_Barrier loop
         Has_Semantic_Barrier := Current.Blocks_Input;
         Current := Current.Next;
      end loop;
      T.Graphics_Input_Blocked :=
        T.Graphics_Queue_Backpressure or else Has_Semantic_Barrier;
   end Refresh_Graphics_Input_Block;

   procedure Enqueue_Graphics_Event
     (T              : in out Terminal;
      Protocol       : Ignored_Graphics_Protocol;
      Row            : Positive;
      Col            : Positive;
      Payload        : String;
      Cancelled      : Boolean := False)
   is separate;

   function Index (T : Terminal; Row : Positive; Col : Positive) return Positive is
     ((Row - 1) * T.Cols + Col);

   function Active_Cells (T : Terminal) return Cell_Array_Access is
     (if T.Active = Primary then T.Primary_Cells else T.Alt_Cells);

   type Image_Diacritic_Array is
     array (Natural range <>) of Common.Code_Point;

   --  Ordered exactly as Kitty's rowcolumn-diacritics.txt.  The position in
   --  this array, starting at zero, is the encoded row, column, or high image
   --  ID byte value.
   Image_Diacritics : constant Image_Diacritic_Array :=
     (16#0305#, 16#030D#, 16#030E#, 16#0310#, 16#0312#, 16#033D#,
      16#033E#, 16#033F#, 16#0346#, 16#034A#, 16#034B#, 16#034C#,
      16#0350#, 16#0351#, 16#0352#, 16#0357#, 16#035B#, 16#0363#,
      16#0364#, 16#0365#, 16#0366#, 16#0367#, 16#0368#, 16#0369#,
      16#036A#, 16#036B#, 16#036C#, 16#036D#, 16#036E#, 16#036F#,
      16#0483#, 16#0484#, 16#0485#, 16#0486#, 16#0487#, 16#0592#,
      16#0593#, 16#0594#, 16#0595#, 16#0597#, 16#0598#, 16#0599#,
      16#059C#, 16#059D#, 16#059E#, 16#059F#, 16#05A0#, 16#05A1#,
      16#05A8#, 16#05A9#, 16#05AB#, 16#05AC#, 16#05AF#, 16#05C4#,
      16#0610#, 16#0611#, 16#0612#, 16#0613#, 16#0614#, 16#0615#,
      16#0616#, 16#0617#, 16#0657#, 16#0658#, 16#0659#, 16#065A#,
      16#065B#, 16#065D#, 16#065E#, 16#06D6#, 16#06D7#, 16#06D8#,
      16#06D9#, 16#06DA#, 16#06DB#, 16#06DC#, 16#06DF#, 16#06E0#,
      16#06E1#, 16#06E2#, 16#06E4#, 16#06E7#, 16#06E8#, 16#06EB#,
      16#06EC#, 16#0730#, 16#0732#, 16#0733#, 16#0735#, 16#0736#,
      16#073A#, 16#073D#, 16#073F#, 16#0740#, 16#0741#, 16#0743#,
      16#0745#, 16#0747#, 16#0749#, 16#074A#, 16#07EB#, 16#07EC#,
      16#07ED#, 16#07EE#, 16#07EF#, 16#07F0#, 16#07F1#, 16#07F3#,
      16#0816#, 16#0817#, 16#0818#, 16#0819#, 16#081B#, 16#081C#,
      16#081D#, 16#081E#, 16#081F#, 16#0820#, 16#0821#, 16#0822#,
      16#0823#, 16#0825#, 16#0826#, 16#0827#, 16#0829#, 16#082A#,
      16#082B#, 16#082C#, 16#082D#, 16#0951#, 16#0953#, 16#0954#,
      16#0F82#, 16#0F83#, 16#0F86#, 16#0F87#, 16#135D#, 16#135E#,
      16#135F#, 16#17DD#, 16#193A#, 16#1A17#, 16#1A75#, 16#1A76#,
      16#1A77#, 16#1A78#, 16#1A79#, 16#1A7A#, 16#1A7B#, 16#1A7C#,
      16#1B6B#, 16#1B6D#, 16#1B6E#, 16#1B6F#, 16#1B70#, 16#1B71#,
      16#1B72#, 16#1B73#, 16#1CD0#, 16#1CD1#, 16#1CD2#, 16#1CDA#,
      16#1CDB#, 16#1CE0#, 16#1DC0#, 16#1DC1#, 16#1DC3#, 16#1DC4#,
      16#1DC5#, 16#1DC6#, 16#1DC7#, 16#1DC8#, 16#1DC9#, 16#1DCB#,
      16#1DCC#, 16#1DD1#, 16#1DD2#, 16#1DD3#, 16#1DD4#, 16#1DD5#,
      16#1DD6#, 16#1DD7#, 16#1DD8#, 16#1DD9#, 16#1DDA#, 16#1DDB#,
      16#1DDC#, 16#1DDD#, 16#1DDE#, 16#1DDF#, 16#1DE0#, 16#1DE1#,
      16#1DE2#, 16#1DE3#, 16#1DE4#, 16#1DE5#, 16#1DE6#, 16#1DFE#,
      16#20D0#, 16#20D1#, 16#20D4#, 16#20D5#, 16#20D6#, 16#20D7#,
      16#20DB#, 16#20DC#, 16#20E1#, 16#20E7#, 16#20E9#, 16#20F0#,
      16#2CEF#, 16#2CF0#, 16#2CF1#, 16#2DE0#, 16#2DE1#, 16#2DE2#,
      16#2DE3#, 16#2DE4#, 16#2DE5#, 16#2DE6#, 16#2DE7#, 16#2DE8#,
      16#2DE9#, 16#2DEA#, 16#2DEB#, 16#2DEC#, 16#2DED#, 16#2DEE#,
      16#2DEF#, 16#2DF0#, 16#2DF1#, 16#2DF2#, 16#2DF3#, 16#2DF4#,
      16#2DF5#, 16#2DF6#, 16#2DF7#, 16#2DF8#, 16#2DF9#, 16#2DFA#,
      16#2DFB#, 16#2DFC#, 16#2DFD#, 16#2DFE#, 16#2DFF#, 16#A66F#,
      16#A67C#, 16#A67D#, 16#A6F0#, 16#A6F1#, 16#A8E0#, 16#A8E1#,
      16#A8E2#, 16#A8E3#, 16#A8E4#, 16#A8E5#, 16#A8E6#, 16#A8E7#,
      16#A8E8#, 16#A8E9#, 16#A8EA#, 16#A8EB#, 16#A8EC#, 16#A8ED#,
      16#A8EE#, 16#A8EF#, 16#A8F0#, 16#A8F1#, 16#AAB0#, 16#AAB2#,
      16#AAB3#, 16#AAB7#, 16#AAB8#, 16#AABE#, 16#AABF#, 16#AAC1#,
      16#FE20#, 16#FE21#, 16#FE22#, 16#FE23#, 16#FE24#, 16#FE25#,
      16#FE26#, 16#10A0F#, 16#10A38#, 16#1D185#, 16#1D186#,
      16#1D187#, 16#1D188#, 16#1D189#, 16#1D1AA#, 16#1D1AB#,
      16#1D1AC#, 16#1D1AD#, 16#1D242#, 16#1D243#, 16#1D244#);

   function Image_Diacritic_Value
     (CP    : Common.Code_Point;
      Value : out Natural) return Boolean
   is
   begin
      for I in Image_Diacritics'Range loop
         if Image_Diacritics (I) = CP then
            Value := I;
            return True;
         end if;
      end loop;
      Value := 0;
      return False;
   end Image_Diacritic_Value;

   function Bounded_Status_Label (Label : String) return String is
   begin
      if Label'Length <= Max_Status_Label_Length then
         return Label;
      end if;

      return Label (Label'First .. Label'First + Max_Status_Label_Length - 4)
        & "...";
   end Bounded_Status_Label;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      if Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Natural_Image;

   type Graphics_Protocol is
     (Graphics_Sixel,
      Graphics_Kitty,
      Graphics_ITerm2);

   procedure Note_Graphics_Protocol
     (T        : in out Terminal;
      Protocol : Graphics_Protocol;
      Payload_Length : Natural;
      Preview        : String := "";
      Enqueue        : Boolean := True;
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

   function Append_Kitty_Chunk_Data
     (T    : in out Terminal;
      Text : String) return Boolean
   is
      Required     : Natural;
      New_Capacity : Natural;
      Replacement  : String_Access := null;
   begin
      if Text'Length = 0 then
         return True;
      elsif Text'Length > T.Graphics_Limits.Transaction_Length
        or else T.Kitty_Chunk_Length >
          T.Graphics_Limits.Transaction_Length - Text'Length
      then
         return False;
      end if;

      Required := T.Kitty_Chunk_Length + Text'Length;
      if Required > T.Kitty_Chunk_Capacity then
         New_Capacity := Natural'Min
           (T.Graphics_Limits.Transaction_Length,
            Natural'Max (4_096, T.Kitty_Chunk_Capacity));
         while New_Capacity < Required loop
            if New_Capacity > T.Graphics_Limits.Transaction_Length / 2 then
               New_Capacity := T.Graphics_Limits.Transaction_Length;
            else
               New_Capacity := New_Capacity * 2;
            end if;
         end loop;
         Replacement := new String (1 .. New_Capacity);
         if T.Kitty_Chunk_Length > 0 then
            Replacement (1 .. T.Kitty_Chunk_Length) :=
              T.Kitty_Chunk_Data (1 .. T.Kitty_Chunk_Length);
         end if;
         if T.Kitty_Chunk_Data /= null then
            Free_String (T.Kitty_Chunk_Data);
         end if;
         T.Kitty_Chunk_Data := Replacement;
         T.Kitty_Chunk_Capacity := New_Capacity;
         Replacement := null;
      end if;
      T.Kitty_Chunk_Data
        (T.Kitty_Chunk_Length + 1 .. Required) := Text;
      T.Kitty_Chunk_Length := Required;
      return True;
   exception
      when Storage_Error =>
         if Replacement /= null then
            Free_String (Replacement);
         end if;
         return False;
   end Append_Kitty_Chunk_Data;

   function Apply_Kitty_Chunk_Quiet
     (T     : in out Terminal;
      Quiet : Natural) return Boolean
   is
      Header_Last : Natural := 0;
      Field_First : Natural := 0;
      Old_Length  : Natural;
   begin
      if T.Kitty_Chunk_Data = null or else T.Kitty_Chunk_Length = 0 then
         return False;
      end if;

      for I in 1 .. T.Kitty_Chunk_Length loop
         if T.Kitty_Chunk_Data (I) = ';' then
            Header_Last := I - 1;
            exit;
         end if;
      end loop;
      if Header_Last = 0 then
         return False;
      end if;

      Field_First := 2;
      for I in 2 .. Header_Last + 1 loop
         if I = Header_Last + 1 or else T.Kitty_Chunk_Data (I) = ',' then
            if I = Field_First + 3
              and then T.Kitty_Chunk_Data (Field_First .. Field_First + 1) =
                "q="
            then
               T.Kitty_Chunk_Data (Field_First + 2) :=
                 Standard.Character'Val
                   (Standard.Character'Pos ('0') + Quiet);
               return True;
            end if;
            Field_First := I + 1;
         end if;
      end loop;

      Old_Length := T.Kitty_Chunk_Length;
      if not Append_Kitty_Chunk_Data (T, "    ") then
         return False;
      end if;
      for I in reverse Header_Last + 1 .. Old_Length loop
         T.Kitty_Chunk_Data (I + 4) := T.Kitty_Chunk_Data (I);
      end loop;
      T.Kitty_Chunk_Data (Header_Last + 1 .. Header_Last + 4) :=
        ",q=" & Standard.Character'Val
          (Standard.Character'Pos ('0') + Quiet);
      return True;
   end Apply_Kitty_Chunk_Quiet;

   procedure Process_Kitty_Graphics_APC
     (T       : in out Terminal;
      Payload : String) is separate;

   procedure Reject_Kitty_Chunk_Interleave (T : in out Terminal) is
   begin
      if not T.Kitty_Chunk_Active then
         return;
      end if;
      if T.Kitty_Chunk_Data /= null and then T.Kitty_Chunk_Length > 0 then
         Note_Graphics_Protocol
           (T,
            Graphics_Kitty,
            T.Kitty_Chunk_Length,
            T.Kitty_Chunk_Data (1 .. T.Kitty_Chunk_Length),
            Kitty_Validation_Error => True);
      end if;
      Advance_Graphics_Transaction (T);
      Clear_Kitty_Chunk (T);
   end Reject_Kitty_Chunk_Interleave;

   function OSC_Slice
     (T     : Terminal;
      First : Positive;
      Last  : Natural) return String
   is
      Result : String (1 .. Last - First + 1);
   begin
      for I in Result'Range loop
         Result (I) := T.OSC_Data (First + I - 1);
      end loop;
      return Result;
   end OSC_Slice;

   function Ignored_String_Slice
     (T     : Terminal;
      First : Positive;
      Last  : Natural) return String
   is
      Result : String (1 .. Last - First + 1);
   begin
      for I in Result'Range loop
         Result (I) := T.Ignored_String_Data (First + I - 1);
      end loop;
      return Result;
   end Ignored_String_Slice;

   procedure Scroll_Down_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1);

   procedure Reset_Graphics_Scroll
     (T : in out Terminal;
      Alternate_Screen : Boolean)
   is
   begin
      if Alternate_Screen then
         T.Alternate_Graphics_Scroll_Sequence := 0;
         T.Alternate_Graphics_Scroll_Head := 0;
         T.Alternate_Graphics_Scroll_Count := 0;
         if T.Alternate_Graphics_Scroll_Events /= null then
            T.Alternate_Graphics_Scroll_Events.all := (others => <>);
         end if;
      else
         T.Primary_Graphics_Scroll_Sequence := 0;
         T.Primary_Graphics_Scroll_Head := 0;
         T.Primary_Graphics_Scroll_Count := 0;
         if T.Primary_Graphics_Scroll_Events /= null then
            T.Primary_Graphics_Scroll_Events.all := (others => <>);
         end if;
      end if;
   end Reset_Graphics_Scroll;

   procedure Note_Graphics_Scroll
     (T         : in out Terminal;
      Direction : Graphics_Scroll_Direction;
      Top       : Positive;
      Bottom    : Positive;
      Count     : Positive)
   is
      Sequence : Graphics_Scroll_Sequence;
      Slot : Natural;
   begin
      if T.Primary_Graphics_Scroll_Events = null
        or else T.Alternate_Graphics_Scroll_Events = null
      then
         return;
      end if;
      if T.Active = Alternate then
         T.Alternate_Graphics_Scroll_Sequence :=
           T.Alternate_Graphics_Scroll_Sequence + 1;
         if T.Alternate_Graphics_Scroll_Sequence = 0 then
            T.Alternate_Graphics_Scroll_Sequence := 1;
         end if;
         Sequence := T.Alternate_Graphics_Scroll_Sequence;
         if T.Alternate_Graphics_Scroll_Count < Max_Graphics_Scroll_Events then
            Slot :=
              (T.Alternate_Graphics_Scroll_Head
               + T.Alternate_Graphics_Scroll_Count)
              mod Max_Graphics_Scroll_Events;
            T.Alternate_Graphics_Scroll_Count :=
              T.Alternate_Graphics_Scroll_Count + 1;
         else
            Slot := T.Alternate_Graphics_Scroll_Head;
            T.Alternate_Graphics_Scroll_Head :=
              (T.Alternate_Graphics_Scroll_Head + 1)
              mod Max_Graphics_Scroll_Events;
         end if;
         T.Alternate_Graphics_Scroll_Events (Slot + 1) :=
           (Sequence, Direction, Top, Bottom, Count);
      else
         T.Primary_Graphics_Scroll_Sequence :=
           T.Primary_Graphics_Scroll_Sequence + 1;
         if T.Primary_Graphics_Scroll_Sequence = 0 then
            T.Primary_Graphics_Scroll_Sequence := 1;
         end if;
         Sequence := T.Primary_Graphics_Scroll_Sequence;
         if T.Primary_Graphics_Scroll_Count < Max_Graphics_Scroll_Events then
            Slot :=
              (T.Primary_Graphics_Scroll_Head
               + T.Primary_Graphics_Scroll_Count)
              mod Max_Graphics_Scroll_Events;
            T.Primary_Graphics_Scroll_Count :=
              T.Primary_Graphics_Scroll_Count + 1;
         else
            Slot := T.Primary_Graphics_Scroll_Head;
            T.Primary_Graphics_Scroll_Head :=
              (T.Primary_Graphics_Scroll_Head + 1)
              mod Max_Graphics_Scroll_Events;
         end if;
         T.Primary_Graphics_Scroll_Events (Slot + 1) :=
           (Sequence, Direction, Top, Bottom, Count);
      end if;
   end Note_Graphics_Scroll;

   procedure New_Line (T : in out Terminal);
   procedure Append_Response_Char
     (T  : in out Terminal;
      Ch : Standard.Character);
   procedure Append_Response_String
     (T    : in out Terminal;
      Text : String);
   procedure Begin_Response (T : in out Terminal);
   procedure End_Response (T : in out Terminal);
   procedure Append_Response_Natural
     (T : in out Terminal;
      N : Natural);

   --  Make Current_Modes.Keyboard_Flags the top of the active screen's
   --  keyboard stack.
   procedure Refresh_Keyboard_Flags (T : in out Terminal);

   --  CSI 48 ; rows ; cols ; height ; width t, the in-band size report.
   procedure Queue_Resize_Report (T : in out Terminal);

   procedure Mark_Dirty (T : in out Terminal; Row : Positive) is
   begin
      if T.Dirty /= null and then Row in T.Dirty'Range then
         T.Dirty (Row) := True;
      end if;
   end Mark_Dirty;

   procedure Mark_All_Dirty (T : in out Terminal) is
   begin
      if T.Dirty /= null then
         for R in T.Dirty'Range loop
            T.Dirty (R) := True;
         end loop;
      end if;
   end Mark_All_Dirty;

   procedure Mark_Cursor_Move
     (T       : in out Terminal;
      Old_Row : Positive)
   is
   begin
      if T.Current_Modes.Cursor_Visible then
         Mark_Dirty (T, Old_Row);
         Mark_Dirty (T, T.Cursor_Row);
      end if;
   end Mark_Cursor_Move;

   procedure Reset_Tab_Stops (T : in out Terminal) is
   begin
      if T.Tab_Stops = null then
         return;
      end if;

      for C in T.Tab_Stops'Range loop
         T.Tab_Stops (C) := C > 1 and then (C - 1) mod 8 = 0;
      end loop;
   end Reset_Tab_Stops;

   function Blank_Cell (Style : Cell_Style) return Cell is
      C : Cell;
   begin
      C.Kind := Empty;
      C.Text.Code_Point := 0;
      C.Text.Width := Width_One;
      C.Text.Attachment_Count := 0;
      C.Text.Attachments := (others => 0);
      C.Style := Style;
      C.Link := (others => <>);
      return C;
   end Blank_Cell;

   procedure Clear_Row
     (T     : in out Terminal;
      Row   : Positive;
      First : Positive;
      Last  : Positive)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      From  : Positive := First;
      To    : Positive := Last;
   begin
      if Cells = null then
         return;
      end if;

      if Cells (Index (T, Row, From)).Kind = Wide_Continuation
        and then From > 1
      then
         From := From - 1;
      end if;

      if Cells (Index (T, Row, To)).Kind = Character
        and then Cells (Index (T, Row, To)).Text.Width = Width_Two
        and then To < T.Cols
      then
         To := To + 1;
      end if;

      for C in From .. To loop
         Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
      end loop;
      Mark_Dirty (T, Row);
   end Clear_Row;

   procedure Reset_Buffer (T : in out Terminal; Cells : Cell_Array_Access) is
   begin
      if Cells = null then
         return;
      end if;

      for I in Cells'Range loop
         Cells (I) := Blank_Cell (T.Current_Style);
      end loop;
      Mark_All_Dirty (T);
   end Reset_Buffer;

   procedure Screen_Alignment_Test (T : in out Terminal) is
      Cells : constant Cell_Array_Access := Active_Cells (T);
   begin
      if Cells = null then
         return;
      end if;

      for I in Cells'Range loop
         Cells (I) :=
           (Kind  => Character,
            Text  => (Code_Point => 16#45#, Width => Width_One, others => <>),
            Style => T.Current_Style,
            Link  => T.Current_Link,
            Image => <>);
      end loop;
      T.Pending_Wrap := False;
      Mark_All_Dirty (T);
   end Screen_Alignment_Test;

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

   procedure Horizontal_Tab_Set (T : in out Terminal) is
   begin
      if T.Tab_Stops /= null then
         T.Tab_Stops (T.Cursor_Col) := True;
      end if;
   end Horizontal_Tab_Set;

   procedure Save_Cursor_State (T : in out Terminal) is
   begin
      T.Saved_Row := T.Cursor_Row;
      T.Saved_Col := T.Cursor_Col;
      T.Saved_Style := T.Current_Style;
      T.Saved_G0_Charset := T.G0_Charset;
      T.Saved_G1_Charset := T.G1_Charset;
      T.Saved_G2_Charset := T.G2_Charset;
      T.Saved_G3_Charset := T.G3_Charset;
      T.Saved_Active_Charset := T.Active_Charset;
   end Save_Cursor_State;

   procedure Restore_Cursor_State (T : in out Terminal) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      T.Cursor_Row := Positive'Min (T.Rows, T.Saved_Row);
      T.Cursor_Col := Positive'Min (T.Cols, T.Saved_Col);
      T.Current_Style := T.Saved_Style;
      T.G0_Charset := T.Saved_G0_Charset;
      T.G1_Charset := T.Saved_G1_Charset;
      T.G2_Charset := T.Saved_G2_Charset;
      T.G3_Charset := T.Saved_G3_Charset;
      T.Active_Charset := T.Saved_Active_Charset;
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Restore_Cursor_State;

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
      Status : out Boolean)
   is
      Count : constant Positive := Rows * Cols;
   begin
      if T.Primary_Cells /= null then
         Free_Cells (T.Primary_Cells);
         T.Primary_Cells := null;
      end if;
      if T.Alt_Cells /= null then
         Free_Cells (T.Alt_Cells);
         T.Alt_Cells := null;
      end if;
      if T.Scrollback /= null then
         Free_Cells (T.Scrollback);
         T.Scrollback := null;
      end if;
      if T.Dirty /= null then
         Free_Dirty (T.Dirty);
         T.Dirty := null;
      end if;
      if T.Tab_Stops /= null then
         Free_Tab_Stops (T.Tab_Stops);
         T.Tab_Stops := null;
      end if;

      if T.Primary_Graphics_Scroll_Events = null then
         T.Primary_Graphics_Scroll_Events :=
           new Graphics_Scroll_Event_Array (1 .. Max_Graphics_Scroll_Events);
         T.Primary_Graphics_Scroll_Events.all := (others => <>);
      end if;
      if T.Alternate_Graphics_Scroll_Events = null then
         T.Alternate_Graphics_Scroll_Events :=
           new Graphics_Scroll_Event_Array (1 .. Max_Graphics_Scroll_Events);
         T.Alternate_Graphics_Scroll_Events.all := (others => <>);
      end if;

      T.Primary_Cells := new Cell_Array (1 .. Count);
      T.Alt_Cells := new Cell_Array (1 .. Count);
      if T.Scrollback_Limit > 0 then
         T.Scrollback := new Cell_Array (1 .. T.Scrollback_Limit * Cols);
      else
         T.Scrollback := null;
      end if;
      T.Dirty := new Dirty_Row_Array (1 .. Rows);
      T.Tab_Stops := new Tab_Stop_Array (1 .. Cols);
      T.Rows := Rows;
      T.Cols := Cols;
      T.Bottom_Margin := Rows;
      T.Scrollback_Rows := 0;
      Status := True;
      Reset_Tab_Stops (T);
      Reset_Buffer (T, T.Primary_Cells);
      Reset_Buffer (T, T.Alt_Cells);
      Mark_All_Dirty (T);
   exception
      when Storage_Error | Constraint_Error =>
         Status := False;
   end Allocate_Buffers;

   procedure Initialize
     (T                : in out Terminal;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural := 10_000;
      Status           : out Initialize_Status)
   is separate;

   procedure Finalize (T : in out Terminal) is
   begin
      Clear_Graphics_Transfer (T);
      Clear_ITerm2_Multipart (T);
      Clear_Graphics_Events (T);
      Clear_Deferred_Input (T);
      if T.OSC_Data /= null then
         Free_String (T.OSC_Data);
      end if;
      T.OSC_Count := 0;
      T.OSC_Capacity := 0;
      if T.Primary_Cells /= null then
         Free_Cells (T.Primary_Cells);
      end if;
      if T.Alt_Cells /= null then
         Free_Cells (T.Alt_Cells);
      end if;
      if T.Scrollback /= null then
         Free_Cells (T.Scrollback);
      end if;
      if T.Dirty /= null then
         Free_Dirty (T.Dirty);
      end if;
      if T.Tab_Stops /= null then
         Free_Tab_Stops (T.Tab_Stops);
      end if;
      if T.Primary_Graphics_Scroll_Events /= null then
         Free_Graphics_Scroll_Events (T.Primary_Graphics_Scroll_Events);
      end if;
      if T.Alternate_Graphics_Scroll_Events /= null then
         Free_Graphics_Scroll_Events (T.Alternate_Graphics_Scroll_Events);
      end if;
      T.Initialized := False;
      T.Last_Graphics := (others => <>);
   end Finalize;

   procedure Append_OSC_Byte
     (T          : in out Terminal;
      Ch         : Standard.Character;
      Overflowed : in out Boolean)
   is
      New_Capacity : Natural;
      Replacement  : String_Access := null;
   begin
      if T.OSC_Count >= Parser.Max_OSC_Length then
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
         Overflowed := True;
         T.State := OSC_Overflow;
      else
         if T.OSC_Count = T.OSC_Capacity then
            if T.OSC_Capacity = 0 then
               New_Capacity := Natural'Min (4 * 1024, Parser.Max_OSC_Length);
            elsif T.OSC_Capacity > Parser.Max_OSC_Length / 2 then
               New_Capacity := Parser.Max_OSC_Length;
            else
               New_Capacity := T.OSC_Capacity * 2;
            end if;
            Replacement := new String (1 .. New_Capacity);
            if T.OSC_Count > 0 then
               Replacement (1 .. T.OSC_Count) :=
                 T.OSC_Data (1 .. T.OSC_Count);
            end if;
            if T.OSC_Data /= null then
               Free_String (T.OSC_Data);
            end if;
            T.OSC_Data := Replacement;
            T.OSC_Capacity := New_Capacity;
            Replacement := null;
         end if;
         T.OSC_Count := T.OSC_Count + 1;
         T.OSC_Data (T.OSC_Count) := Ch;
      end if;
   exception
      when Storage_Error =>
         if Replacement /= null then
            Free_String (Replacement);
         end if;
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
         Overflowed := True;
         T.State := OSC_Overflow;
   end Append_OSC_Byte;

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
         T.Graphics_Capabilities.Kitty_Direct_RGBA or else T.Graphics_Capabilities.Kitty_Direct_PNG);
      Capability ("kgfx-shm", T.Graphics_Capabilities.Kitty_Shared_Memory);
      Capability ("kgfx-jpeg", T.Graphics_Capabilities.Kitty_Direct_JPEG);
      Capability ("kgfx-gif", T.Graphics_Capabilities.Kitty_Direct_GIF);
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
   is
      Is_Full_Graphics_Capture : constant Boolean :=
        (T.Ignored_String_Is_DCS
         and then
           (T.Graphics_Transfer_Length > 0
            or else
              (T.Ignored_String_Count = 0
               and then Ch in '0' .. '9' | ';' | '?' | 'q' | 't')))
        or else
          (T.Ignored_String_Is_APC
           and then
             (T.Graphics_Transfer_Length > 0
              or else (T.Ignored_String_Count = 0 and then Ch = 'G')));

      procedure Append_Graphics_Byte is
         New_Capacity : Natural;
         Replacement  : String_Access;
      begin
         if T.Graphics_Transfer_Length >=
           T.Graphics_Limits.Transaction_Length
         then
            if T.Kitty_Chunk_Active and then T.Ignored_String_Is_APC then
               Advance_Graphics_Transaction (T);
               Clear_Kitty_Chunk (T);
            end if;
            T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
            Overflowed := True;
            Clear_Graphics_Transfer (T);
            T.State := Ignored_String_Overflow;
            return;
         end if;

         if T.Graphics_Transfer_Length = T.Graphics_Transfer_Capacity then
            if T.Graphics_Transfer_Capacity = 0 then
               New_Capacity := Natural'Min
                 (4 * 1024, T.Graphics_Limits.Transaction_Length);
            elsif T.Graphics_Transfer_Capacity >
              T.Graphics_Limits.Transaction_Length / 2
            then
               New_Capacity := T.Graphics_Limits.Transaction_Length;
            else
               New_Capacity := T.Graphics_Transfer_Capacity * 2;
            end if;

            Replacement := new String (1 .. New_Capacity);
            if T.Graphics_Transfer_Length > 0 then
               Replacement (1 .. T.Graphics_Transfer_Length) :=
                 T.Graphics_Transfer (1 .. T.Graphics_Transfer_Length);
            end if;
            if T.Graphics_Transfer /= null then
               Free_String (T.Graphics_Transfer);
            end if;
            T.Graphics_Transfer := Replacement;
            T.Graphics_Transfer_Capacity := New_Capacity;
         end if;

         T.Graphics_Transfer_Length := T.Graphics_Transfer_Length + 1;
         T.Graphics_Transfer (T.Graphics_Transfer_Length) := Ch;
      exception
         when Storage_Error =>
            if T.Kitty_Chunk_Active and then T.Ignored_String_Is_APC then
               Advance_Graphics_Transaction (T);
               Clear_Kitty_Chunk (T);
            end if;
            T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
            Overflowed := True;
            Clear_Graphics_Transfer (T);
            T.State := Ignored_String_Overflow;
      end Append_Graphics_Byte;
   begin
      if Is_Full_Graphics_Capture then
         Append_Graphics_Byte;
         if T.State = Ignored_String_Overflow then
            return;
         end if;

         --  Retain the legacy prefix for Snapshot.Graphics and non-graphics
         --  DCS parsing without allowing that preview bound to terminate a
         --  complete Kitty, Sixel, or tmux passthrough transaction.
         if T.Ignored_String_Count < Parser.Max_Escape_Length then
            T.Ignored_String_Count := T.Ignored_String_Count + 1;
            T.Ignored_String_Data (T.Ignored_String_Count) := Ch;
         end if;
      elsif T.Ignored_String_Count >= Parser.Max_Escape_Length then
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
         Overflowed := True;
         T.State := Ignored_String_Overflow;
      else
         T.Ignored_String_Count := T.Ignored_String_Count + 1;
         T.Ignored_String_Data (T.Ignored_String_Count) := Ch;
      end if;
   end Append_Ignored_String_Byte;

   procedure Start_Ignored_String
     (T      : in out Terminal;
      Is_DCS : Boolean;
      Is_APC : Boolean := False)
   is
   begin
      Clear_Graphics_Transfer (T);
      T.Ignored_String_Data := (others => ASCII.NUL);
      T.Ignored_String_Count := 0;
      T.Ignored_String_Is_DCS := Is_DCS;
      T.Ignored_String_Is_APC := Is_APC;
      T.State := Ignored_String;
   end Start_Ignored_String;

   function In_String_Control (State : Parser_State) return Boolean is
     (State = OSC
      or else State = OSC_Escape
      or else State = OSC_Overflow
      or else State = OSC_Overflow_Escape
      or else State = Ignored_String
      or else State = Ignored_String_Escape
      or else State = Ignored_String_Overflow
      or else State = Ignored_String_Overflow_Escape);

   --  Ring buffer: logical Row 1 is the oldest, living physically at
   --  Scrollback_Head, wrapping modulo the limit. Every reader and writer goes
   --  through here, so head-awareness is confined to this one expression.
   function Scrollback_Index
     (T   : Terminal;
      Row : Positive;
      Col : Positive) return Positive
   is
     (((T.Scrollback_Head + Row - 1) mod T.Scrollback_Limit) * T.Cols + Col);

   procedure Append_Scrollback_Row
     (T      : in out Terminal;
      Cells  : Cell_Array_Access;
      Source : Positive)
   is
   begin
      if T.Scrollback_Limit = 0
        or else T.Scrollback = null
        or else Cells = null
      then
         return;
      end if;

      if T.Scrollback_Rows = T.Scrollback_Limit then
         --  Full: drop the oldest row by advancing the head one slot. The new
         --  row is then written into the vacated slot as the newest logical row
         --  (Scrollback_Index (T, Scrollback_Rows, ..) resolves there), so no row
         --  is memmoved -- append is O(Cols) instead of O(Limit x Cols).
         T.Scrollback_Head := (T.Scrollback_Head + 1) mod T.Scrollback_Limit;
      else
         T.Scrollback_Rows := T.Scrollback_Rows + 1;
      end if;

      for C in 1 .. T.Cols loop
         T.Scrollback (Scrollback_Index (T, T.Scrollback_Rows, C)) :=
           Cells (Index (T, Source, C));
      end loop;
   end Append_Scrollback_Row;

   procedure Scroll_Up_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
   begin
      if Cells = null or else Top >= Bottom then
         return;
      end if;

      for N in 1 .. Count loop
         if T.Active = Primary and then Top = 1 and then Bottom = T.Rows then
            Append_Scrollback_Row (T, Cells, Top);
         end if;

         for R in Top .. Bottom - 1 loop
            for C in 1 .. T.Cols loop
               Cells (Index (T, R, C)) := Cells (Index (T, R + 1, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
         Clear_Row (T, Bottom, 1, T.Cols);
      end loop;
      Note_Graphics_Scroll
        (T, Graphics_Scroll_Up, Top, Bottom, Count);
   end Scroll_Up_Region;

   procedure Scroll_Down_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
   begin
      if Cells = null or else Top >= Bottom then
         return;
      end if;

      for N in 1 .. Count loop
         for R in reverse Top + 1 .. Bottom loop
            for C in 1 .. T.Cols loop
               Cells (Index (T, R, C)) := Cells (Index (T, R - 1, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
         Clear_Row (T, Top, 1, T.Cols);
      end loop;
      Note_Graphics_Scroll
        (T, Graphics_Scroll_Down, Top, Bottom, Count);
   end Scroll_Down_Region;

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

   function Is_Wide (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
   begin
      return
        (V in 16#1100# .. 16#115F#)
        or else (V in 16#2E80# .. 16#A4CF#)
        or else (V in 16#AC00# .. 16#D7A3#)
        or else (V in 16#F900# .. 16#FAFF#)
        or else (V in 16#FE10# .. 16#FE6F#)
        or else (V in 16#FF00# .. 16#FF60#)
        or else (V in 16#FFE0# .. 16#FFE6#)
        or else (V in 16#1F000# .. 16#1FAFF#)
        or else (V in 16#20000# .. 16#3FFFD#);
   end Is_Wide;

   function Is_Emoji_Variation_Base (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
   begin
      return
        V = 16#00A9#
        or else V = 16#00AE#
        or else V = 16#203C#
        or else V = 16#2049#
        or else V = 16#2122#
        or else V = 16#2139#
        or else (V in 16#2194# .. 16#21AA#)
        or else (V in 16#231A# .. 16#231B#)
        or else V = 16#2328#
        or else V = 16#23CF#
        or else (V in 16#23E9# .. 16#23F3#)
        or else (V in 16#23F8# .. 16#23FA#)
        or else V = 16#24C2#
        or else (V in 16#25AA# .. 16#25AB#)
        or else V = 16#25B6#
        or else V = 16#25C0#
        or else (V in 16#25FB# .. 16#25FE#)
        or else (V in 16#2600# .. 16#27BF#)
        or else (V in 16#2934# .. 16#2935#)
        or else (V in 16#2B05# .. 16#2B55#)
        or else V = 16#3030#
        or else V = 16#303D#
        or else V = 16#3297#
        or else V = 16#3299#;
   end Is_Emoji_Variation_Base;

   function Is_Keycap_Base (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
   begin
      return
        V = 16#23#
        or else V = 16#2A#
        or else (V in 16#30# .. 16#39#);
   end Is_Keycap_Base;

   function Is_Regional_Indicator (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
   begin
      return V in 16#1F1E6# .. 16#1F1FF#;
   end Is_Regional_Indicator;

   function Is_Emoji_Modifier (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
   begin
      return V in 16#1F3FB# .. 16#1F3FF#;
   end Is_Emoji_Modifier;

   function Is_Zero_Width (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
      Image_Value : Natural;
   begin
      return
        Image_Diacritic_Value (CP, Image_Value)
        or else V = 16#200C#
        or else V = 16#200D#
        or else (V in 16#0300# .. 16#036F#)
        or else V = 16#034F#
        or else (V in 16#0483# .. 16#0489#)
        or else (V in 16#0591# .. 16#05BD#)
        or else V = 16#05BF#
        or else (V in 16#05C1# .. 16#05C2#)
        or else (V in 16#05C4# .. 16#05C5#)
        or else V = 16#05C7#
        or else (V in 16#0610# .. 16#061A#)
        or else V = 16#061C#
        or else (V in 16#064B# .. 16#065F#)
        or else V = 16#0670#
        or else (V in 16#06D6# .. 16#06ED#)
        or else V = 16#0711#
        or else (V in 16#0730# .. 16#074A#)
        or else (V in 16#07A6# .. 16#07B0#)
        or else (V in 16#07EB# .. 16#07F3#)
        or else (V in 16#0816# .. 16#0819#)
        or else (V in 16#081B# .. 16#0823#)
        or else (V in 16#0825# .. 16#0827#)
        or else (V in 16#0829# .. 16#082D#)
        or else (V in 16#0859# .. 16#085B#)
        or else (V in 16#08D3# .. 16#08FF#)
        or else (V in 16#0900# .. 16#0903#)
        or else V = 16#093A#
        or else V = 16#093C#
        or else (V in 16#0941# .. 16#0948#)
        or else V = 16#094D#
        or else (V in 16#0951# .. 16#0957#)
        or else (V in 16#0962# .. 16#0963#)
        or else (V in 16#180B# .. 16#180F#)
        or else (V in 16#1AB0# .. 16#1AFF#)
        or else (V in 16#1DC0# .. 16#1DFF#)
        or else (V in 16#200B# .. 16#200F#)
        or else (V in 16#202A# .. 16#202E#)
        or else (V in 16#2060# .. 16#206F#)
        or else (V in 16#20D0# .. 16#20FF#)
        or else (V in 16#FE00# .. 16#FE0F#)
        or else (V in 16#FE20# .. 16#FE2F#)
        or else V = 16#FEFF#
        or else (V in 16#E0000# .. 16#E007F#)
        or else (V in 16#E0100# .. 16#E01EF#);
   end Is_Zero_Width;

   function Is_Renderable_Attachment
     (CP : Common.Code_Point) return Boolean
   is
      V : constant Natural := Natural (CP);
   begin
      return
        (V in 16#0300# .. 16#036F#)
        or else (V in 16#0483# .. 16#0489#)
        or else (V in 16#0591# .. 16#05BD#)
        or else V = 16#05BF#
        or else (V in 16#05C1# .. 16#05C2#)
        or else (V in 16#05C4# .. 16#05C5#)
        or else V = 16#05C7#
        or else (V in 16#0610# .. 16#061A#)
        or else (V in 16#064B# .. 16#065F#)
        or else V = 16#0670#
        or else (V in 16#06D6# .. 16#06ED#)
        or else V = 16#0711#
        or else (V in 16#0730# .. 16#074A#)
        or else (V in 16#07A6# .. 16#07B0#)
        or else (V in 16#07EB# .. 16#07F3#)
        or else (V in 16#0816# .. 16#0819#)
        or else (V in 16#081B# .. 16#0823#)
        or else (V in 16#0825# .. 16#0827#)
        or else (V in 16#0829# .. 16#082D#)
        or else (V in 16#0859# .. 16#085B#)
        or else (V in 16#08D3# .. 16#08FF#)
        or else (V in 16#0900# .. 16#0903#)
        or else V = 16#093A#
        or else V = 16#093C#
        or else (V in 16#0941# .. 16#0948#)
        or else V = 16#094D#
        or else (V in 16#0951# .. 16#0957#)
        or else (V in 16#0962# .. 16#0963#)
        or else (V in 16#1AB0# .. 16#1AFF#)
        or else (V in 16#1DC0# .. 16#1DFF#)
        or else (V in 16#20D0# .. 16#20FF#)
        or else (V in 16#FE20# .. 16#FE2F#);
   end Is_Renderable_Attachment;

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
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      Last  : constant Positive :=
        (if New_Width = Width_Two and then Col < T.Cols then Col + 1 else Col);
   begin
      if Cells = null then
         return;
      end if;

      if Cells (Index (T, Row, Col)).Kind = Wide_Continuation and then Col > 1 then
         Cells (Index (T, Row, Col - 1)) := Blank_Cell (T.Current_Style);
      end if;

      for C in Col .. Last loop
         if Cells (Index (T, Row, C)).Kind = Character
           and then Cells (Index (T, Row, C)).Text.Width = Width_Two
           and then C < T.Cols
         then
            Cells (Index (T, Row, C + 1)) := Blank_Cell (T.Current_Style);
         elsif Cells (Index (T, Row, C)).Kind = Wide_Continuation and then C > 1 then
            Cells (Index (T, Row, C - 1)) := Blank_Cell (T.Current_Style);
         end if;
      end loop;
   end Clear_Wide_Overlap;

   procedure Normalize_Wide_Row (T : in out Terminal; Row : Positive) is
      Cells : constant Cell_Array_Access := Active_Cells (T);
   begin
      if Cells = null then
         return;
      end if;

      for C in 1 .. T.Cols loop
         if Cells (Index (T, Row, C)).Kind = Wide_Continuation then
            if C = 1
              or else Cells (Index (T, Row, C - 1)).Kind /= Character
              or else Cells (Index (T, Row, C - 1)).Text.Width /= Width_Two
            then
               Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
            end if;
         elsif Cells (Index (T, Row, C)).Kind = Character
           and then Cells (Index (T, Row, C)).Text.Width = Width_Two
         then
            if C = T.Cols
              or else Cells (Index (T, Row, C + 1)).Kind /= Wide_Continuation
            then
               Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
            end if;
         end if;
      end loop;
   end Normalize_Wide_Row;

   procedure Shift_Row_Right
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      Blank_Last : constant Positive := Positive'Min (T.Cols, Col + Distance - 1);
   begin
      if Cells = null then
         return;
      end if;

      if Col + Distance <= T.Cols then
         for C in reverse Col + Distance .. T.Cols loop
            Cells (Index (T, Row, C)) := Cells (Index (T, Row, C - Distance));
         end loop;
      end if;

      for C in Col .. Blank_Last loop
         Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
      end loop;
      Normalize_Wide_Row (T, Row);
      Mark_Dirty (T, Row);
   end Shift_Row_Right;

   procedure Shift_Row_Left
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      Blank_First : Positive;
   begin
      if Cells = null then
         return;
      end if;

      if Col + Distance <= T.Cols then
         for C in Col .. T.Cols - Distance loop
            Cells (Index (T, Row, C)) := Cells (Index (T, Row, C + Distance));
         end loop;
         Blank_First := T.Cols - Distance + 1;
      else
         Blank_First := Col;
      end if;

      for C in Blank_First .. T.Cols loop
         Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
      end loop;
      Normalize_Wide_Row (T, Row);
      Mark_Dirty (T, Row);
   end Shift_Row_Left;

   procedure Erase_Characters
     (T     : in out Terminal;
      Row   : Positive;
      Col   : Positive;
      Count : Positive)
   is
      Last  : constant Positive := Positive'Min (T.Cols, Col + Count - 1);
   begin
      Clear_Row (T, Row, Col, Last);
   end Erase_Characters;

   procedure Insert_Blank_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive)
   is
      Cells  : constant Cell_Array_Access := Active_Cells (T);
      Amount : Natural;
   begin
      if Cells = null or else Row < T.Top_Margin or else Row > T.Bottom_Margin then
         return;
      end if;

      Amount := Natural'Min (Count, T.Bottom_Margin - Row + 1);

      if Amount = 0 then
         return;
      end if;

      if Row + Amount <= T.Bottom_Margin then
         for R in reverse Row + Amount .. T.Bottom_Margin loop
            for C in 1 .. T.Cols loop
               Cells (Index (T, R, C)) := Cells (Index (T, R - Amount, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
      end if;

      for R in Row .. Positive'Min (T.Bottom_Margin, Row + Amount - 1) loop
         Clear_Row (T, R, 1, T.Cols);
      end loop;
      Note_Graphics_Scroll
        (T,
         Graphics_Scroll_Down,
         Row,
         T.Bottom_Margin,
         Positive (Amount));
   end Insert_Blank_Lines;

   procedure Delete_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive)
   is
      Cells  : constant Cell_Array_Access := Active_Cells (T);
      Amount : Natural;
   begin
      if Cells = null or else Row < T.Top_Margin or else Row > T.Bottom_Margin then
         return;
      end if;

      Amount := Natural'Min (Count, T.Bottom_Margin - Row + 1);

      if Amount = 0 then
         return;
      end if;

      if Row + Amount <= T.Bottom_Margin then
         for R in Row .. T.Bottom_Margin - Amount loop
            for C in 1 .. T.Cols loop
               Cells (Index (T, R, C)) := Cells (Index (T, R + Amount, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
      end if;

      for R in Positive'Max (Row, T.Bottom_Margin - Amount + 1) .. T.Bottom_Margin loop
         Clear_Row (T, R, 1, T.Cols);
      end loop;
      Note_Graphics_Scroll
        (T,
         Graphics_Scroll_Up,
         Row,
         T.Bottom_Margin,
         Positive (Amount));
   end Delete_Lines;

   procedure Put_Code_Point
     (T : in out Terminal; CP : Common.Code_Point) is separate;

   procedure Clear_CSI (T : in out Terminal) is
   begin
      T.CSI_Private := ASCII.NUL;
      T.CSI_Params := (others => 0);
      T.CSI_Set := (others => False);
      T.CSI_Separators := (others => ASCII.NUL);
      T.CSI_Count := 0;
      T.CSI_Intermediates := (others => ASCII.NUL);
      T.CSI_Intermediate_Count := 0;
   end Clear_CSI;

   function Param
     (T       : Terminal;
      N       : Positive;
      Default : Natural) return Natural
   is
   begin
      if N <= T.CSI_Count and then T.CSI_Set (N) then
         return T.CSI_Params (N);
      else
         return Default;
      end if;
   end Param;

   function Param_Separator
     (T : Terminal;
      N : Positive) return Standard.Character
   is
   begin
      if N <= T.CSI_Count then
         return T.CSI_Separators (N);
      else
         return ASCII.NUL;
      end if;
   end Param_Separator;

   procedure Append_Response_Byte
     (T : in out Terminal;
      B : Common.Bytes.Byte)
   is
   begin
      if T.Response_Transaction_Overflowed then
         return;
      elsif T.Response_Length < Max_Response_Length then
         T.Response_Length := T.Response_Length + 1;
         T.Responses (T.Response_Length) := B;
      elsif T.Response_Transaction_Active then
         T.Response_Transaction_Overflowed := True;
      else
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
      end if;
   end Append_Response_Byte;

   procedure Begin_Response (T : in out Terminal) is
   begin
      pragma Assert (not T.Response_Transaction_Active);
      T.Response_Transaction_Start := T.Response_Length;
      T.Response_Transaction_Active := True;
      T.Response_Transaction_Overflowed := False;
   end Begin_Response;

   procedure End_Response (T : in out Terminal) is
   begin
      pragma Assert (T.Response_Transaction_Active);
      if T.Response_Transaction_Overflowed then
         T.Response_Length := T.Response_Transaction_Start;
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
      end if;
      T.Response_Transaction_Start := 0;
      T.Response_Transaction_Active := False;
      T.Response_Transaction_Overflowed := False;
   end End_Response;

   procedure Append_Response_Char
     (T  : in out Terminal;
      Ch : Standard.Character)
   is
   begin
      Append_Response_Byte (T, Common.Bytes.Byte (Standard.Character'Pos (Ch)));
   end Append_Response_Char;

   procedure Append_Response_String
     (T    : in out Terminal;
      Text : String)
   is
   begin
      for Ch of Text loop
         Append_Response_Char (T, Ch);
      end loop;
   end Append_Response_String;

   procedure Append_Response_Natural
     (T : in out Terminal;
      N : Natural)
   is
      Text : constant String := Natural'Image (N);
   begin
      for I in Text'Range loop
         if Text (I) /= ' ' then
            Append_Response_Char (T, Text (I));
         end if;
      end loop;
   end Append_Response_Natural;

   procedure Append_Response_Graphics_ID
     (T     : in out Terminal;
      Value : Graphics_ID)
   is
      Text : constant String := Graphics_ID'Image (Value);
   begin
      for Ch of Text loop
         if Ch /= ' ' then
            Append_Response_Char (T, Ch);
         end if;
      end loop;
   end Append_Response_Graphics_ID;

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

   procedure Append_SGR_Status (T : in out Terminal) is
      First : Boolean := True;

      procedure Param (N : Natural) is
      begin
         if First then
            First := False;
         else
            Append_Response_Char (T, ';');
         end if;
         Append_Response_Natural (T, N);
      end Param;

      procedure Color_Params
        (C      : Color;
         Base_8 : Natural;
         Bright : Natural;
         Selector : Natural)
      is
      begin
         case C.Kind is
            when Default =>
               null;
            when Indexed =>
               if C.Index <= 7 then
                  Param (Base_8 + C.Index);
               elsif C.Index <= 15 then
                  Param (Bright + C.Index - 8);
               else
                  Param (Selector);
                  Param (5);
                  Param (C.Index);
               end if;
            when RGB =>
               Param (Selector);
               Param (2);
               Param (C.R);
               Param (C.G);
               Param (C.B);
         end case;
      end Color_Params;

      procedure Extended_Color_Params
        (C        : Color;
         Selector : Natural)
      is
      begin
         case C.Kind is
            when Default =>
               null;
            when Indexed =>
               Param (Selector);
               Param (5);
               Param (C.Index);
            when RGB =>
               Param (Selector);
               Param (2);
               Param (C.R);
               Param (C.G);
               Param (C.B);
         end case;
      end Extended_Color_Params;
   begin
      if T.Current_Style.Bold then
         Param (1);
      end if;
      if T.Current_Style.Faint then
         Param (2);
      end if;
      if T.Current_Style.Italic then
         Param (3);
      end if;
      if T.Current_Style.Underline then
         if T.Current_Style.Underline_Kind = Underline_Single then
            Param (4);
         else
            if First then
               First := False;
            else
               Append_Response_Char (T, ';');
            end if;
            Append_Response_Char (T, '4');
            Append_Response_Char (T, ':');
            case T.Current_Style.Underline_Kind is
               when Underline_Single =>
                  Append_Response_Char (T, '1');
               when Underline_Double =>
                  Append_Response_Char (T, '2');
               when Underline_Curly =>
                  Append_Response_Char (T, '3');
               when Underline_Dotted =>
                  Append_Response_Char (T, '4');
               when Underline_Dashed =>
                  Append_Response_Char (T, '5');
            end case;
         end if;
      end if;
      if T.Current_Style.Blink then
         Param (5);
      end if;
      if T.Current_Style.Inverse then
         Param (7);
      end if;
      if T.Current_Style.Conceal then
         Param (8);
      end if;
      if T.Current_Style.Strikethrough then
         Param (9);
      end if;
      if T.Current_Style.Overline then
         Param (53);
      end if;

      Color_Params (T.Current_Style.Foreground, 30, 90, 38);
      Color_Params (T.Current_Style.Background, 40, 100, 48);
      Extended_Color_Params (T.Current_Style.Underline_Color, 58);

      if First then
         Param (0);
      end if;
      Append_Response_Char (T, 'm');
   end Append_SGR_Status;

   procedure Finish_Ignored_String (T : in out Terminal) is separate;

   procedure Queue_Device_Status_Report
     (T    : in out Terminal;
      Kind : Natural)
   is
      Valid_Report : constant Boolean := T.CSI_Count <= 1;

      procedure Append_Private_DSR (Text : String) is
      begin
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '?');
         Append_Response_String (T, Text);
         Append_Response_Char (T, 'n');
      end Append_Private_DSR;
   begin
      Begin_Response (T);
      case Kind is
         when 5 =>
            if not Valid_Report then
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            elsif T.CSI_Private = ASCII.NUL then
               Append_Response_Char (T, ASCII.ESC);
               Append_Response_Char (T, '[');
               Append_Response_Char (T, '0');
               Append_Response_Char (T, 'n');
            elsif T.CSI_Private = '?' then
               Append_Response_Char (T, ASCII.ESC);
               Append_Response_Char (T, '[');
               Append_Response_Char (T, '?');
               Append_Response_Char (T, '0');
               Append_Response_Char (T, 'n');
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 6 =>
            if not Valid_Report
              or else T.CSI_Private not in ASCII.NUL | '?'
            then
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            else
               Append_Response_Char (T, ASCII.ESC);
               Append_Response_Char (T, '[');
               if T.CSI_Private = '?' then
                  Append_Response_Char (T, '?');
               end if;
               Append_Response_Natural (T, T.Cursor_Row);
               Append_Response_Char (T, ';');
               Append_Response_Natural (T, T.Cursor_Col);
               Append_Response_Char (T, 'R');
            end if;
         when 15 =>
            if T.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("11");
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 25 =>
            if T.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("20");
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 26 =>
            if T.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("27;1;0;0");
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 53 | 55 =>
            if T.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("50");
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 56 =>
            if T.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("57;0");
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when others =>
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end case;
      End_Response (T);
   end Queue_Device_Status_Report;

   procedure Queue_Device_Attributes
     (T : in out Terminal)
   is
   begin
      Begin_Response (T);
      if T.CSI_Private = ASCII.NUL
        and then T.CSI_Count <= 1
        and then Param (T, 1, 0) = 0
      then
         Append_Response_String (T, ASCII.ESC & "[?62;4;22c");
      elsif T.CSI_Private = '>'
        and then T.CSI_Count <= 1
        and then Param (T, 1, 0) = 0
      then
         Append_Response_String (T, ASCII.ESC & "[>0;1;0c");
      else
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end if;
      End_Response (T);
   end Queue_Device_Attributes;

   procedure Queue_Window_Operation_Report
     (T      : in out Terminal;
      Number : Natural)
   is
      Target : constant Natural := Param (T, 2, 0);

      function Valid_Report return Boolean is
        (T.CSI_Private = ASCII.NUL and then T.CSI_Count <= 1);

      function Valid_Title_Stack_Target return Boolean is
        (T.CSI_Private = ASCII.NUL
         and then T.CSI_Count <= 2
         and then Target in 0 .. 2);
   begin
      Begin_Response (T);
      if T.CSI_Private = ASCII.NUL and then Number in 1 .. 10 then
         null;
      elsif Valid_Report and then Number = 11 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '1');
         Append_Response_Char (T, 't');
      elsif Valid_Report and then Number = 13 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '3');
         Append_Response_Char (T, ';');
         Append_Response_Char (T, '0');
         Append_Response_Char (T, ';');
         Append_Response_Char (T, '0');
         Append_Response_Char (T, 't');
      elsif Valid_Report and then Number = 14 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '4');
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Window_Pixel_Height);
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Window_Pixel_Width);
         Append_Response_Char (T, 't');
      elsif Valid_Report and then Number = 15 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '5');
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Window_Pixel_Height);
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Window_Pixel_Width);
         Append_Response_Char (T, 't');
      elsif Valid_Report and then Number = 16 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '6');
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Cell_Pixel_Height);
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Cell_Pixel_Width);
         Append_Response_Char (T, 't');
      elsif Valid_Report and then Number = 18 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '8');
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Rows);
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Cols);
         Append_Response_Char (T, 't');
      elsif Valid_Report and then Number = 19 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '9');
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Rows);
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Cols);
         Append_Response_Char (T, 't');
      elsif Valid_Report and then Number = 20 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, ']');
         Append_Response_Char (T, 'L');
         for I in 1 .. T.Window_Title.Length loop
            Append_Response_Char (T, T.Window_Title.Text (I));
         end loop;
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '\');
      elsif Valid_Report and then Number = 21 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, ']');
         Append_Response_Char (T, 'l');
         for I in 1 .. T.Window_Title.Length loop
            Append_Response_Char (T, T.Window_Title.Text (I));
         end loop;
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '\');
      elsif Number = 22
        and then Valid_Title_Stack_Target
      then
         T.Saved_Window_Title := T.Window_Title;
         T.Saved_Window_Title_Valid := True;
      elsif Number = 23
        and then Valid_Title_Stack_Target
      then
         if T.Saved_Window_Title_Valid then
            T.Window_Title := T.Saved_Window_Title;
         end if;
      else
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end if;
      End_Response (T);
   end Queue_Window_Operation_Report;

   function Mode_Report_State
     (T       : Terminal;
      Prefix  : Standard.Character;
      Number  : Natural)
      return Natural
   is
   begin
      if Prefix = '?' then
         case Number is
            when 1 =>
               return (if T.Current_Modes.Application_Cursor then 1 else 2);
            when 6 =>
               return (if T.Current_Modes.Origin_Mode then 1 else 2);
            when 7 =>
               return (if T.Current_Modes.Autowrap then 1 else 2);
            when 12 =>
               return (if T.Current_Modes.Cursor_Blinking then 1 else 2);
            when 25 =>
               return (if T.Current_Modes.Cursor_Visible then 1 else 2);
            when 66 =>
               return (if T.Current_Modes.Application_Keypad then 1 else 2);
            when 67 =>
               return (if T.Current_Modes.Backarrow_Key_Backspace then 1 else 2);
            when 47 | 1047 | 1049 =>
               return (if T.Current_Modes.Alternate_Screen then 1 else 2);
            when 1048 =>
               return 2;
            when 1000 =>
               return (if T.Current_Modes.Mouse_Button then 1 else 2);
            when 1002 =>
               return (if T.Current_Modes.Mouse_Drag then 1 else 2);
            when 1003 =>
               return (if T.Current_Modes.Mouse_Any_Event then 1 else 2);
            when 1004 =>
               return (if T.Current_Modes.Focus_Reporting then 1 else 2);
            when 1005 =>
               return (if T.Current_Modes.Mouse_UTF8 then 1 else 2);
            when 1006 =>
               return (if T.Current_Modes.Mouse_SGR then 1 else 2);
            when 1015 =>
               return (if T.Current_Modes.Mouse_URXVT then 1 else 2);
            when 2004 =>
               return (if T.Current_Modes.Bracketed_Paste then 1 else 2);
            when 2026 =>
               return (if T.Current_Modes.Synchronized_Update then 1 else 2);
            when 2048 =>
               return (if T.Current_Modes.In_Band_Resize then 1 else 2);
            when others =>
               return 0;
         end case;
      elsif Prefix = ASCII.NUL and then Number = 2 then
         return (if T.Current_Modes.Keyboard_Locked then 1 else 2);
      elsif Prefix = ASCII.NUL and then Number = 4 then
         return (if T.Current_Modes.Insert_Mode then 1 else 2);
      elsif Prefix = ASCII.NUL and then Number = 20 then
         return (if T.Current_Modes.Linefeed_New_Line then 1 else 2);
      else
         return 0;
      end if;
   end Mode_Report_State;

   procedure Queue_Mode_Report (T : in out Terminal) is
      Number : constant Natural := Param (T, 1, 0);
      State  : constant Natural :=
        Mode_Report_State (T, T.CSI_Private, Number);
   begin
      if T.CSI_Count /= 1
        or else not T.CSI_Set (1)
        or else (T.CSI_Private /= ASCII.NUL and then T.CSI_Private /= '?')
      then
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         return;
      end if;

      Begin_Response (T);
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_Char (T, '[');
      if T.CSI_Private /= ASCII.NUL then
         Append_Response_Char (T, T.CSI_Private);
      end if;
      Append_Response_Natural (T, Number);
      Append_Response_Char (T, ';');
      Append_Response_Natural (T, State);
      Append_Response_Char (T, '$');
      Append_Response_Char (T, 'y');
      End_Response (T);
   end Queue_Mode_Report;

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
      if Col <= 1 then
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
   is
   begin
      if not T.Has_Last_Printable then
         return;
      end if;

      for I in 1 .. Count loop
         Put_Code_Point (T, T.Last_Printable);
      end loop;
   end Repeat_Last_Printable;

   procedure Set_Mode (T : in out Terminal; Number : Natural; Enable : Boolean) is separate;

   procedure Apply_SGR (T : in out Terminal) is separate;

   procedure Soft_Reset (T : in out Terminal) is
      Old_Row : constant Positive := T.Cursor_Row;
      Keep_Alternate : constant Boolean := T.Current_Modes.Alternate_Screen;
   begin
      T.Current_Style := (others => <>);
      T.Saved_Style := (others => <>);
      T.Current_Modes :=
        Default_Modes (Alternate_Screen => Keep_Alternate);
      T.Cursor_Row := 1;
      T.Cursor_Col := 1;
      T.Current_Cursor_Shape := Cursor_Block;
      T.Current_Cursor_Blinking := False;
      T.Saved_Row := 1;
      T.Saved_Col := 1;
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
      T.Pending_Wrap := False;
      T.Top_Margin := 1;
      T.Bottom_Margin := T.Rows;
      T.Last_Printable := 0;
      T.Has_Last_Printable := False;
      Refresh_Keyboard_Flags (T);
      Mark_Cursor_Move (T, Old_Row);
   end Soft_Reset;

   --  The progressive keyboard enhancement controls: CSI > flags u pushes,
   --  CSI < n u pops n, CSI = flags ; mode u sets (1), adds (2), or removes
   --  (3) flags, and CSI ? u asks for the current ones.
   procedure Apply_Keyboard_Protocol (T : in out Terminal) is
      Stack : Keyboard_Stack renames T.Keyboard_Stacks (T.Current_Modes.Alternate_Screen);
      Flags : constant Natural := Natural'Min (Param (T, 1, 0), 31) mod (Supported_Keyboard_Flags + 1);
   begin
      case T.CSI_Private is
         when '>' =>
            if Stack.Depth = Max_Keyboard_Stack_Depth then
               --  A full stack loses its oldest entry, as kitty's does.
               Stack.Flags (1 .. Max_Keyboard_Stack_Depth - 1) := Stack.Flags (2 .. Max_Keyboard_Stack_Depth);
            else
               Stack.Depth := Stack.Depth + 1;
            end if;
            Stack.Flags (Stack.Depth) := Flags;
         when '<' =>
            Stack.Depth := Stack.Depth - Natural'Min (Stack.Depth, Natural'Max (1, Param (T, 1, 1)));
         when '=' =>
            if Stack.Depth = 0 then
               Stack.Depth := 1;
               Stack.Flags (1) := 0;
            end if;

            case Param (T, 2, 1) is
               when 1 =>
                  Stack.Flags (Stack.Depth) := Flags;
               when 2 =>
                  Stack.Flags (Stack.Depth) :=
                    (if Flags mod 2 = 1 or else Stack.Flags (Stack.Depth) mod 2 = 1 then 1 else 0);
               when 3 =>
                  Stack.Flags (Stack.Depth) :=
                    (if Flags mod 2 = 1 then 0 else Stack.Flags (Stack.Depth) mod 2);
               when others =>
                  T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end case;
         when '?' =>
            Begin_Response (T);
            Append_Response_String (T, ASCII.ESC & "[?");
            Append_Response_Natural (T, T.Current_Modes.Keyboard_Flags);
            Append_Response_Char (T, 'u');
            End_Response (T);
         when others =>
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end case;

      Refresh_Keyboard_Flags (T);
   end Apply_Keyboard_Protocol;

   --  XTVERSION: DCS > | name version ST.
   procedure Queue_Version_Report (T : in out Terminal) is
   begin
      if T.CSI_Count > 1 or else Param (T, 1, 0) /= 0 then
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
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
     (T : in out Terminal; Final : Standard.Character) is separate;

   procedure Execute_C0 (T : in out Terminal; B : Common.Bytes.Byte) is
   begin
      case Natural (B) is
         when 7 =>
            null;
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
            T.State := Escape;
         when others =>
            null;
      end case;
   end Execute_C0;

   procedure Emit_UTF8_Replacement (T : in out Terminal) is
   begin
      T.Diag.Malformed_UTF8 := T.Diag.Malformed_UTF8 + 1;
      Put_Code_Point (T, 16#FFFD#);
      T.UTF8_Need := 0;
      T.UTF8_Seen := 0;
      T.UTF8_Accum := 0;
      T.UTF8_Min := 0;
   end Emit_UTF8_Replacement;

   procedure Recover_Incomplete_UTF8 (T : in out Terminal) is
   begin
      if T.State = Ground and then T.UTF8_Need > 0 then
         Emit_UTF8_Replacement (T);
      end if;
   end Recover_Incomplete_UTF8;

   procedure Decode_Printable (T : in out Terminal; B : Common.Bytes.Byte) is
      V : constant Natural := Natural (B);

      function Charset_For (Slot : Charset_Slot) return Charset_Kind is
      begin
         case Slot is
            when G0 =>
               return T.G0_Charset;
            when G1 =>
               return T.G1_Charset;
            when G2 =>
               return T.G2_Charset;
            when G3 =>
               return T.G3_Charset;
         end case;
      end Charset_For;

      function Map_DEC_Special_Graphics
        (CP : Common.Code_Point) return Common.Code_Point
      is
         V : constant Natural := Natural (CP);
      begin
         case V is
            when 16#60# => return 16#25C6#;
            when 16#61# => return 16#2592#;
            when 16#62# => return 16#2409#;
            when 16#63# => return 16#240C#;
            when 16#64# => return 16#240D#;
            when 16#65# => return 16#240A#;
            when 16#66# => return 16#00B0#;
            when 16#67# => return 16#00B1#;
            when 16#68# => return 16#2424#;
            when 16#69# => return 16#240B#;
            when 16#6A# => return 16#2518#;
            when 16#6B# => return 16#2510#;
            when 16#6C# => return 16#250C#;
            when 16#6D# => return 16#2514#;
            when 16#6E# => return 16#253C#;
            when 16#6F# => return 16#23BA#;
            when 16#70# => return 16#23BB#;
            when 16#71# => return 16#2500#;
            when 16#72# => return 16#23BC#;
            when 16#73# => return 16#23BD#;
            when 16#74# => return 16#251C#;
            when 16#75# => return 16#2524#;
            when 16#76# => return 16#2534#;
            when 16#77# => return 16#252C#;
            when 16#78# => return 16#2502#;
            when 16#79# => return 16#2264#;
            when 16#7A# => return 16#2265#;
            when 16#7B# => return 16#03C0#;
            when 16#7C# => return 16#2260#;
            when 16#7D# => return 16#00A3#;
            when 16#7E# => return 16#00B7#;
            when others => return CP;
         end case;
      end Map_DEC_Special_Graphics;

      procedure Put_Mapped_ASCII (Slot : Charset_Slot) is
         CP : Common.Code_Point := Common.Code_Point (V);
      begin
         if Charset_For (Slot) = DEC_Special_Graphics then
            CP := Map_DEC_Special_Graphics (CP);
         end if;
         Put_Code_Point (T, CP);
      end Put_Mapped_ASCII;

      procedure Put_Decoded_Code_Point (CP : Natural) is
         V : constant Natural := CP;
      begin
         case V is
            when 16#84# =>
               Index_Control (T);
            when 16#85# =>
               Next_Line_Control (T);
            when 16#88# =>
               Horizontal_Tab_Set (T);
            when 16#8C# =>
               Reset_Terminal (T);
            when 16#8D# =>
               Reverse_Index_Control (T);
            when 16#8E# =>
               T.Single_Shift_Charset := G2;
               T.State := Single_Shift;
            when 16#8F# =>
               T.Single_Shift_Charset := G3;
               T.State := Single_Shift;
            when 16#90# =>
               Start_Ignored_String (T, Is_DCS => True);
            when 16#98# | 16#9E# =>
               Start_Ignored_String (T, Is_DCS => False);
            when 16#9F# =>
               Start_Ignored_String
                 (T, Is_DCS => False, Is_APC => True);
            when 16#9B# =>
               Clear_CSI (T);
               T.State := CSI;
            when 16#9C# =>
               null;
            when 16#9D# =>
               T.OSC_Count := 0;
               T.State := OSC;
            when others =>
               Put_Code_Point (T, Common.Code_Point (CP));
         end case;
      end Put_Decoded_Code_Point;
   begin
      if T.UTF8_Need = 0 then
         if V < 16#80# then
            Put_Mapped_ASCII (T.Active_Charset);
         elsif V in 16#C2# .. 16#DF# then
            T.UTF8_Need := 1;
            T.UTF8_Seen := 0;
            T.UTF8_Accum := V mod 32;
            T.UTF8_Min := 16#80#;
         elsif V in 16#E0# .. 16#EF# then
            T.UTF8_Need := 2;
            T.UTF8_Seen := 0;
            T.UTF8_Accum := V mod 16;
            T.UTF8_Min := 16#800#;
         elsif V in 16#F0# .. 16#F4# then
            T.UTF8_Need := 3;
            T.UTF8_Seen := 0;
            T.UTF8_Accum := V mod 8;
            T.UTF8_Min := 16#10000#;
         else
            Emit_UTF8_Replacement (T);
         end if;
      elsif V in 16#80# .. 16#BF# then
         T.UTF8_Accum := T.UTF8_Accum * 64 + (V mod 64);
         T.UTF8_Seen := T.UTF8_Seen + 1;
         if T.UTF8_Seen = T.UTF8_Need then
            if T.UTF8_Accum < T.UTF8_Min
              or else T.UTF8_Accum in 16#D800# .. 16#DFFF#
              or else T.UTF8_Accum > 16#10FFFF#
            then
               Emit_UTF8_Replacement (T);
            else
               Put_Decoded_Code_Point (T.UTF8_Accum);
               T.UTF8_Need := 0;
               T.UTF8_Seen := 0;
               T.UTF8_Accum := 0;
               T.UTF8_Min := 0;
            end if;
         end if;
      else
         Emit_UTF8_Replacement (T);
         Decode_Printable (T, B);
      end if;
   end Decode_Printable;

   function Append_Deferred_Input
     (T    : in out Terminal;
      Data : Core_Byte_Array) return Boolean
   is
      Required     : Natural;
      New_Capacity : Natural;
      Replacement  : Core_Byte_Array_Access := null;
   begin
      if Data'Length = 0 then
         return True;
      end if;
      if Data'Length > T.Graphics_Limits.Deferred_Input_Bytes
        or else T.Deferred_Input_Length >
          T.Graphics_Limits.Deferred_Input_Bytes - Data'Length
      then
         T.Diag.Queue_Overflow := T.Diag.Queue_Overflow + 1;
         return False;
      end if;

      Required := T.Deferred_Input_Length + Data'Length;
      if Required > T.Deferred_Input_Capacity then
         New_Capacity := Natural'Min
           (T.Graphics_Limits.Deferred_Input_Bytes,
            Natural'Max (4_096, T.Deferred_Input_Capacity));
         while New_Capacity < Required loop
            if New_Capacity > T.Graphics_Limits.Deferred_Input_Bytes / 2 then
               New_Capacity := T.Graphics_Limits.Deferred_Input_Bytes;
            else
               New_Capacity := New_Capacity * 2;
            end if;
         end loop;
         Replacement := new Core_Byte_Array (1 .. New_Capacity);
         if T.Deferred_Input_Length > 0 and then T.Deferred_Input /= null then
            Replacement (1 .. T.Deferred_Input_Length) :=
              T.Deferred_Input (1 .. T.Deferred_Input_Length);
         end if;
         if T.Deferred_Input /= null then
            Free_Deferred_Input (T.Deferred_Input);
         end if;
         T.Deferred_Input := Replacement;
         T.Deferred_Input_Capacity := New_Capacity;
         Replacement := null;
      end if;

      for I in Data'Range loop
         T.Deferred_Input
           (T.Deferred_Input_Length + I - Data'First + 1) := Data (I);
      end loop;
      T.Deferred_Input_Length := Required;
      return True;
   exception
      when Storage_Error =>
         if Replacement /= null then
            Free_Deferred_Input (Replacement);
         end if;
         T.Diag.Queue_Overflow := T.Diag.Queue_Overflow + 1;
         return False;
   end Append_Deferred_Input;

   procedure Resume_Deferred_Input (T : in out Terminal) is
      Saved  : Core_Byte_Array_Access := T.Deferred_Input;
      Length : constant Natural := T.Deferred_Input_Length;
      Status : Feed_Status;
   begin
      T.Deferred_Input := null;
      T.Deferred_Input_Length := 0;
      T.Deferred_Input_Capacity := 0;
      if Saved = null or else Length = 0 then
         return;
      end if;

      Feed (T, Saved (1 .. Length), Status);
      Free_Deferred_Input (Saved);
   exception
      when others =>
         if Saved /= null then
            Free_Deferred_Input (Saved);
         end if;
         raise;
   end Resume_Deferred_Input;

   procedure Feed
     (T      : in out Terminal;
      Data   : Core_Byte_Array;
      Status : out Feed_Status) is separate;

   procedure Resize
     (T      : in out Terminal;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Resize_Status) is separate;

   procedure Snapshot
     (T : Terminal;
      S : in out Render_Snapshot) is separate;

   function Snapshot (T : Terminal) return Render_Snapshot is
      S : Render_Snapshot;
   begin
      Snapshot (T, S);
      return S;
   exception
      when others =>
         Release (S);
         raise;
   end Snapshot;

   procedure Release (S : in out Render_Snapshot) is
   begin
      if S.Cells /= null then
         Free_Cells (S.Cells);
         S.Cells := null;
      end if;
      if S.Dirty /= null then
         Free_Dirty (S.Dirty);
         S.Dirty := null;
      end if;
      if S.Graphics_Scroll_Events /= null then
         Free_Graphics_Scroll_Events (S.Graphics_Scroll_Events);
         S.Graphics_Scroll_Events := null;
      end if;
      S.Rows := 0;
      S.Cols := 0;
      S.Graphics_Stream := 0;
      S.Alternate_Screen := False;
      S.Screen_Generation := 0;
      S.Scrollback_Offset := 0;
      S.Scrollback_Rows := 0;
      S.Graphics_Scroll_Current := 0;
      S.Graphics_Scroll_Oldest := 0;
      S.Graphics_Scroll_Count := 0;
      S.Image_Cell_Count := 0;
      S.Cursor := (others => <>);
   end Release;

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
      T.Graphics_Capabilities := Profile;
   end Set_Graphics_Capabilities;

   procedure Set_Graphics_Stream_ID
     (T  : in out Terminal;
      ID : Graphics_Stream_ID) is
   begin
      T.Graphics_Stream := ID;
      T.Last_Graphics.Stream_ID := ID;
   end Set_Graphics_Stream_ID;

   procedure Set_Graphics_Resource_Limits
     (T      : in out Terminal;
      Limits : Graphics_Resource_Limits)
   is
      Was_Blocked : constant Boolean := T.Graphics_Input_Blocked;
   begin
      if T.Kitty_Chunk_Active
        and then T.Kitty_Chunk_Length > Limits.Transaction_Length
      then
         Advance_Graphics_Transaction (T);
         Clear_Kitty_Chunk (T);
      end if;
      T.Graphics_Limits := Limits;
      Refresh_Graphics_Input_Block (T);
      if Was_Blocked and then not T.Graphics_Input_Blocked then
         Resume_Deferred_Input (T);
      end if;
   end Set_Graphics_Resource_Limits;

   function Graphics_Resource_Limit
     (T : Terminal) return Graphics_Resource_Limits is
     (T.Graphics_Limits);

   function Modes (T : Terminal) return Mode_Snapshot is
   begin
      return T.Current_Modes;
   end Modes;

   function Diagnostics (T : Terminal) return Diagnostic_Snapshot is
   begin
      return T.Diag;
   end Diagnostics;

   function Initialize_Status_Label (Status : Initialize_Status) return String is
   begin
      case Status is
         when Ok =>
            return "Initialize: Ok";
         when Invalid_Size =>
            return "Initialize: Invalid Size";
         when Invalid_Scrollback_Limit =>
            return "Initialize: Invalid Scrollback Limit";
         when Allocation_Failed =>
            return "Initialize: Allocation Failed";
      end case;
   end Initialize_Status_Label;

   function Feed_Status_Label (Status : Feed_Status) return String is
   begin
      case Status is
         when Ok =>
            return "Feed: Ok";
         when Parser_Recovered =>
            return "Feed: Parser Recovered";
         when Parser_Overflow =>
            return "Feed: Parser Overflow";
         when Invalid_State =>
            return "Feed: Invalid State";
      end case;
   end Feed_Status_Label;

   function Diagnostics_Status_Label
     (Diagnostics : Diagnostic_Snapshot) return String
   is
      Total : constant Natural :=
        Diagnostics.Malformed_UTF8
        + Diagnostics.Ignored_Escape
        + Diagnostics.Parser_Overflow
        + Diagnostics.Queue_Overflow
        + Diagnostics.Unsupported_Sequence
        + Diagnostics.Text_Cluster_Overflow
        + Diagnostics.Graphics_Protocol_Ignored
        + Diagnostics.Multiplexer_Passthrough;
   begin
      if Total = 0 then
         return "Diagnostics: clean";
      end if;

      return Bounded_Status_Label
        ("Diagnostics: issues=" & Natural_Image (Total)
         & " utf8=" & Natural_Image (Diagnostics.Malformed_UTF8)
         & " esc=" & Natural_Image (Diagnostics.Ignored_Escape)
         & " parse=" & Natural_Image (Diagnostics.Parser_Overflow)
         & " queue=" & Natural_Image (Diagnostics.Queue_Overflow)
         & " unsup=" & Natural_Image (Diagnostics.Unsupported_Sequence)
         & " gfx=" & Natural_Image (Diagnostics.Graphics_Protocol_Ignored)
         & " mux=" & Natural_Image (Diagnostics.Multiplexer_Passthrough));
   end Diagnostics_Status_Label;

   function Title (T : Terminal) return Title_Text is
   begin
      return T.Window_Title;
   end Title;

   function Clipboard (T : Terminal) return Clipboard_Request is
   begin
      return T.Clipboard_Data;
   end Clipboard;

   procedure Clear_Clipboard (T : in out Terminal) is
   begin
      T.Clipboard_Data := (others => <>);
   end Clear_Clipboard;

   function Scrollback_Row_Count (T : Terminal) return Natural is
   begin
      return T.Scrollback_Rows;
   end Scrollback_Row_Count;

   function Pending_Response_Length (T : Terminal) return Natural is
   begin
      return T.Response_Length;
   end Pending_Response_Length;

   function Pending_Graphics_Event_Count (T : Terminal) return Natural is
   begin
      return T.Graphics_Event_Count;
   end Pending_Graphics_Event_Count;

   function Pending_Graphics_Byte_Count (T : Terminal) return Natural is
   begin
      return T.Graphics_Byte_Count;
   end Pending_Graphics_Byte_Count;

   procedure Peek_Graphics_Event
     (T     : Terminal;
      Event : out Graphics_Event)
   is
      Node          : constant Graphics_Event_Node_Access := T.Graphics_Head;
      Preview_Count : Natural;
   begin
      Event := (others => <>);
      if Node = null then
         return;
      end if;

      Event.Pending := True;
      Event.Cancelled := Node.Cancelled;
      Event.Protocol := Node.Protocol;
      Event.Stream_ID := Node.Stream_ID;
      Event.Sequence := Node.Sequence;
      Event.Transaction_Generation := Node.Transaction_Generation;
      Event.Alternate_Screen := Node.Alternate_Screen;
      Event.Screen_Generation := Node.Screen_Generation;
      Event.Scroll_Sequence := Node.Scroll_Sequence;
      Event.Sixel_Private_Colors := Node.Sixel_Private_Colors;
      Event.Row := Node.Row;
      Event.Col := Node.Col;
      Event.Payload_Length := Node.Payload_Length;
      Preview_Count :=
        Natural'Min (Node.Payload_Length, Max_Graphics_Preview_Length);
      Event.Preview_Length := Preview_Count;
      if Preview_Count > 0 and then Node.Payload /= null then
         Event.Preview (1 .. Preview_Count) :=
           Node.Payload (1 .. Preview_Count);
      end if;
   end Peek_Graphics_Event;

   function Graphics_Event_Payload
     (T     : Terminal;
      Event : Graphics_Event) return String
   is
      Node : constant Graphics_Event_Node_Access := T.Graphics_Head;
   begin
      if Node = null
        or else not Event.Pending
        or else Event.Protocol /= Node.Protocol
        or else Event.Stream_ID /= Node.Stream_ID
        or else Event.Sequence /= Node.Sequence
        or else Node.Payload = null
      then
         return "";
      end if;
      return Node.Payload.all;
   end Graphics_Event_Payload;

   procedure Discard_Graphics_Event (T : in out Terminal) is
      Was_Blocked : constant Boolean := T.Graphics_Input_Blocked;
   begin
      Drop_Graphics_Head (T);
      Refresh_Graphics_Input_Block (T);
      if Was_Blocked and then not T.Graphics_Input_Blocked then
         Resume_Deferred_Input (T);
      end if;
   end Discard_Graphics_Event;

   procedure Complete_Graphics_Event
     (T      : in out Terminal;
      Event  : Graphics_Event;
      Result : Kitty_Graphics_Result)
   is separate;

   procedure Read_Graphics_Event
     (T            : in out Terminal;
      Event        : out Graphics_Event;
      Buffer       : out Core_Byte_Array;
      Last         : out Natural;
      End_Of_Event : out Boolean)
   is
      Node          : Graphics_Event_Node_Access := T.Graphics_Head;
      Remaining     : Natural;
      Count         : Natural;
   begin
      Peek_Graphics_Event (T, Event);
      Last := 0;
      End_Of_Event := True;
      if Node = null then
         return;
      end if;

      Remaining := Node.Payload_Length - Node.Read_Offset;
      Count := Natural'Min (Buffer'Length, Remaining);
      if Count > 0 and then Node.Payload /= null then
         for I in 1 .. Count loop
            Buffer (Buffer'First + I - 1) :=
              Common.Bytes.Byte
                (Standard.Character'Pos
                   (Node.Payload (Node.Read_Offset + I)));
         end loop;
         Node.Read_Offset := Node.Read_Offset + Count;
         Last := Count;
      end if;

      End_Of_Event := Node.Read_Offset = Node.Payload_Length;
      if End_Of_Event then
         declare
            Was_Blocked : constant Boolean := T.Graphics_Input_Blocked;
         begin
            Drop_Graphics_Head (T);
            Refresh_Graphics_Input_Block (T);
            if Was_Blocked and then not T.Graphics_Input_Blocked then
               Resume_Deferred_Input (T);
            end if;
         end;
      end if;
   end Read_Graphics_Event;

   procedure Read_Response
     (T      : in out Terminal;
      Buffer : out Common.Bytes.Byte_Array;
      Last   : out Natural)
   is
      Count : constant Natural :=
        Natural'Min (Buffer'Length, T.Response_Length);
   begin
      Last := Count;
      if Count > 0 then
         for I in 1 .. Count loop
            Buffer (Buffer'First + I - 1) := T.Responses (I);
         end loop;

         if Count < T.Response_Length then
            for I in 1 .. T.Response_Length - Count loop
               T.Responses (I) := T.Responses (I + Count);
            end loop;
         end if;
         T.Response_Length := T.Response_Length - Count;
      end if;
   end Read_Response;

   procedure Clear_Damage (T : in out Terminal) is
   begin
      if T.Dirty /= null then
         for R in T.Dirty'Range loop
            T.Dirty (R) := False;
         end loop;
      end if;
   end Clear_Damage;

   function Cell_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell
   is
   begin
      if S.Cells = null or else Row > S.Rows or else Col > S.Cols then
         return (others => <>);
      end if;
      return S.Cells ((Row - 1) * S.Cols + Col);
   end Cell_At;

   function Scrollback_Cell_At
     (T   : Terminal;
      Row : Positive;
      Col : Positive) return Cell
   is
   begin
      if T.Scrollback = null
        or else Row > T.Scrollback_Rows
        or else Col > T.Cols
      then
         return (others => <>);
      end if;

      return T.Scrollback (Scrollback_Index (T, Row, Col));
   end Scrollback_Cell_At;
end Terminal.Core;
