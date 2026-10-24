with Ada.Unchecked_Deallocation;
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
   is
      Stored : String_Access := null;
      Node   : Graphics_Event_Node_Access := null;
      Blocks_Input : Boolean := False;
      Old_Chunk_Active : constant Boolean := T.Kitty_Chunk_Active;
      Old_Chunk_Blocks : constant Boolean := T.Kitty_Chunk_Blocks_Input;
   begin
      if T.Graphics_Event_Count >= T.Graphics_Limits.Pending_Events
        or else Payload'Length > T.Graphics_Limits.Pending_Bytes
        or else T.Graphics_Byte_Count >
          T.Graphics_Limits.Pending_Bytes - Payload'Length
      then
         T.Diag.Queue_Overflow := T.Diag.Queue_Overflow + 1;
         T.Graphics_Queue_Overflowed := True;
         return;
      end if;

      Blocks_Input :=
        not Cancelled
        and then
          (case Protocol is
              when Kitty_Graphics => Kitty_Command_Blocks_Input (T, Payload),
              when ITerm2_Graphics => ITerm2_Command_Blocks_Input (Payload),
              when Sixel_Graphics => False,
              when No_Graphics => False);
      Stored := new String'(Payload);
      Node := new Graphics_Event_Node'
        (Protocol       => Protocol,
         Cancelled      => Cancelled,
         Sequence       => T.Next_Graphics_Sequence,
         Transaction_Generation => T.Graphics_Transaction,
         Blocks_Input   => Blocks_Input,
         Alternate_Screen => T.Active = Alternate,
         Screen_Generation =>
           (if T.Active = Alternate
            then T.Alternate_Graphics_Generation
            else T.Primary_Graphics_Generation),
         Scroll_Sequence =>
           (if T.Active = Alternate
            then T.Alternate_Graphics_Scroll_Sequence
            else T.Primary_Graphics_Scroll_Sequence),
         Sixel_Private_Colors => T.Current_Modes.Sixel_Private_Colors,
         Row            => Row,
         Col            => Col,
         Payload_Length => Payload'Length,
         Payload        => Stored,
         Read_Offset    => 0,
         Next           => null);

      if T.Graphics_Tail = null then
         T.Graphics_Head := Node;
      else
         T.Graphics_Tail.Next := Node;
      end if;
      T.Graphics_Tail := Node;
      T.Graphics_Event_Count := T.Graphics_Event_Count + 1;
      T.Graphics_Byte_Count := T.Graphics_Byte_Count + Payload'Length;
      T.Graphics_Queue_Backpressure :=
        T.Graphics_Event_Count >= T.Graphics_Limits.Pending_Events
        or else
          (T.Graphics_Event_Count > 0
           and then
             T.Graphics_Limits.Pending_Bytes - T.Graphics_Byte_Count <
               Natural'Min
                 (T.Graphics_Limits.Transaction_Length,
                  T.Graphics_Limits.Pending_Bytes));
      T.Graphics_Input_Blocked :=
        T.Graphics_Input_Blocked
        or else Blocks_Input
        or else T.Graphics_Queue_Backpressure;
      T.Last_Graphics.Stream_ID := T.Graphics_Stream;
      T.Last_Graphics.Sequence := Node.Sequence;
      T.Last_Graphics.Transaction_Generation := T.Graphics_Transaction;
      T.Last_Graphics.Alternate_Screen := Node.Alternate_Screen;
      T.Last_Graphics.Screen_Generation := Node.Screen_Generation;
      T.Last_Graphics.Scroll_Sequence := Node.Scroll_Sequence;
      T.Last_Graphics.Sixel_Private_Colors := Node.Sixel_Private_Colors;
      T.Next_Graphics_Sequence := T.Next_Graphics_Sequence + 1;
      if T.Next_Graphics_Sequence = 0 then
         T.Next_Graphics_Sequence := 1;
      end if;
   exception
      when Storage_Error =>
         if Node /= null then
            Free_Graphics_Node (Node);
         end if;
         if Stored /= null then
            Free_String (Stored);
         end if;
         T.Kitty_Chunk_Active := Old_Chunk_Active;
         T.Kitty_Chunk_Blocks_Input := Old_Chunk_Blocks;
         T.Diag.Queue_Overflow := T.Diag.Queue_Overflow + 1;
         T.Graphics_Queue_Overflowed := True;
   end Enqueue_Graphics_Event;

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
   is
      Preview_Length : constant Graphics_Preview_Length_Range :=
        Graphics_Preview_Length_Range'Min
          (Preview'Length, Max_Graphics_Preview_Length);
      Previous_Graphics : constant Graphics_Event := T.Last_Graphics;
   begin
      T.Diag.Graphics_Protocol_Ignored :=
        T.Diag.Graphics_Protocol_Ignored + 1;
      T.Diag.Last_Graphics_Payload_Length := Payload_Length;
      T.Last_Graphics.Pending := True;
      T.Last_Graphics.Cancelled := Kitty_Validation_Error;
      T.Last_Graphics.Stream_ID := T.Graphics_Stream;
      T.Last_Graphics.Sequence := 0;
      T.Last_Graphics.Transaction_Generation := T.Graphics_Transaction;
      T.Last_Graphics.Alternate_Screen := T.Active = Alternate;
      T.Last_Graphics.Screen_Generation :=
        (if T.Active = Alternate
         then T.Alternate_Graphics_Generation
         else T.Primary_Graphics_Generation);
      T.Last_Graphics.Scroll_Sequence :=
        (if T.Active = Alternate
         then T.Alternate_Graphics_Scroll_Sequence
         else T.Primary_Graphics_Scroll_Sequence);
      T.Last_Graphics.Sixel_Private_Colors :=
        T.Current_Modes.Sixel_Private_Colors;
      T.Last_Graphics.Row :=
        (if At_Row = 0 then T.Cursor_Row
         else Positive'Min (T.Rows, Positive (At_Row)));
      T.Last_Graphics.Col :=
        (if At_Col = 0 then T.Cursor_Col
         else Positive'Min (T.Cols, Positive (At_Col)));
      T.Last_Graphics.Payload_Length := Payload_Length;
      T.Last_Graphics.Preview_Length := Preview_Length;
      T.Last_Graphics.Preview := (others => ASCII.NUL);
      for I in 1 .. Preview_Length loop
         T.Last_Graphics.Preview (I) := Preview (Preview'First + I - 1);
      end loop;

      case Protocol is
         when Graphics_Sixel =>
            T.Diag.Sixel_Ignored := T.Diag.Sixel_Ignored + 1;
            T.Diag.Last_Graphics_Protocol := Sixel_Graphics;
            T.Last_Graphics.Protocol := Sixel_Graphics;
         when Graphics_Kitty =>
            T.Diag.Kitty_Graphics_Ignored :=
              T.Diag.Kitty_Graphics_Ignored + 1;
            T.Diag.Last_Graphics_Protocol := Kitty_Graphics;
            T.Last_Graphics.Protocol := Kitty_Graphics;
         when Graphics_ITerm2 =>
            T.Diag.ITerm2_Image_Ignored :=
              T.Diag.ITerm2_Image_Ignored + 1;
            T.Diag.Last_Graphics_Protocol := ITerm2_Graphics;
            T.Last_Graphics.Protocol := ITerm2_Graphics;
      end case;

      if Enqueue then
         Enqueue_Graphics_Event
           (T,
            T.Last_Graphics.Protocol,
            T.Last_Graphics.Row,
            T.Last_Graphics.Col,
            Preview,
            Cancelled => Kitty_Validation_Error);
         --  The compatibility snapshot must never publish a command rejected
         --  by the bounded queue.  Successful queue entries always receive a
         --  nonzero sequence number from Enqueue_Graphics_Event.
         if T.Last_Graphics.Sequence = 0 then
            T.Last_Graphics := Previous_Graphics;
         end if;
      end if;
   end Note_Graphics_Protocol;

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
   is
      Result       : Kitty_Chunk_Control;
      Header_Last  : Natural := 0;
      Field_First  : Natural;
      More_Seen    : Boolean := False;
      Quiet_Seen   : Boolean := False;
      Action_Seen  : Boolean := False;
   begin
      if Payload'Length < 2 or else Payload (Payload'First) /= 'G' then
         return Result;
      end if;

      for I in Payload'First + 1 .. Payload'Last loop
         if Payload (I) = ';' then
            Header_Last := I - 1;
            Result.Data_First := I + 1;
            exit;
         end if;
      end loop;
      if Header_Last = 0 then
         Header_Last := Payload'Last;
         Result.Data_First := 0;
      end if;

      Field_First := Payload'First + 1;
      if Field_First <= Header_Last then
         for I in Field_First .. Header_Last + 1 loop
            if I = Header_Last + 1 or else Payload (I) = ',' then
               declare
                  Field_Last : constant Natural := I - 1;
                  Key        : Standard.Character;
                  Value_First : Natural;
                  Value_Last  : Natural;
               begin
                  if Field_Last < Field_First + 2
                    or else Payload (Field_First + 1) /= '='
                  then
                     return Result;
                  end if;
                  Key := Payload (Field_First);
                  Value_First := Field_First + 2;
                  Value_Last := Field_Last;

                  if Continuation then
                     case Key is
                        when 'm' =>
                           if More_Seen
                             or else Value_First /= Value_Last
                             or else Payload (Value_First) not in '0' | '1'
                           then
                              return Result;
                           end if;
                           More_Seen := True;
                           Result.More_Specified := True;
                           Result.More := Payload (Value_First) = '1';
                           Result.More_Value_Index := Value_First;
                        when 'q' =>
                           if Quiet_Seen
                             or else Value_First /= Value_Last
                             or else Payload (Value_First) not in '0' | '1' | '2'
                           then
                              return Result;
                           end if;
                           Quiet_Seen := True;
                           Result.Quiet_Specified := True;
                           Result.Quiet :=
                             Standard.Character'Pos (Payload (Value_First))
                               - Standard.Character'Pos ('0');
                        when 'a' =>
                           if Action_Seen
                             or else Value_First /= Value_Last
                             or else Payload (Value_First) /= 'f'
                             or else Initial_Action /= 'f'
                           then
                              return Result;
                           end if;
                           Action_Seen := True;
                        when others =>
                           return Result;
                     end case;
                  else
                     case Key is
                        when 'm' =>
                           if More_Seen
                             or else Value_First /= Value_Last
                             or else Payload (Value_First) not in '0' | '1'
                           then
                              return Result;
                           end if;
                           More_Seen := True;
                           Result.More_Specified := True;
                           Result.More := Payload (Value_First) = '1';
                           Result.More_Value_Index := Value_First;
                        when 'a' =>
                           if Value_First /= Value_Last then
                              return Result;
                           end if;
                           Result.Action := Payload (Value_First);
                        when 't' =>
                           if Value_First /= Value_Last then
                              return Result;
                           end if;
                           Result.Transmission := Payload (Value_First);
                        when 'q' =>
                           if Quiet_Seen
                             or else Value_First /= Value_Last
                             or else Payload (Value_First) not in '0' | '1' | '2'
                           then
                              return Result;
                           end if;
                           Quiet_Seen := True;
                           Result.Quiet_Specified := True;
                           Result.Quiet :=
                             Standard.Character'Pos (Payload (Value_First))
                               - Standard.Character'Pos ('0');
                        when others =>
                           null;
                     end case;
                  end if;
               end;
               Field_First := I + 1;
            end if;
         end loop;
      end if;

      Result.Valid :=
        (not Continuation
         or else
           (Result.More_Specified
            and then
              (Initial_Action /= 'f' or else Action_Seen)));
      return Result;
   end Parse_Kitty_Chunk_Control;

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
      Payload : String)
   is
      Control : constant Kitty_Chunk_Control :=
        Parse_Kitty_Chunk_Control
          (Payload,
           Continuation => T.Kitty_Chunk_Active,
           Initial_Action => T.Kitty_Chunk_Action);
      Data_Length : constant Natural :=
        (if Control.Data_First = 0
           or else Control.Data_First > Payload'Last
         then 0
         else Payload'Last - Control.Data_First + 1);

      procedure Queue_Current
        (Text       : String;
         Invalid    : Boolean := False) is
      begin
         Note_Graphics_Protocol
           (T,
            Graphics_Kitty,
            Text'Length,
            Text,
            Kitty_Validation_Error => Invalid);
      end Queue_Current;

      procedure Queue_Partial_Error is
      begin
         if T.Kitty_Chunk_Data /= null and then T.Kitty_Chunk_Length > 0 then
            Queue_Current
              (T.Kitty_Chunk_Data (1 .. T.Kitty_Chunk_Length),
               Invalid => True);
         else
            Queue_Current (Payload, Invalid => True);
         end if;
         Advance_Graphics_Transaction (T);
         Clear_Kitty_Chunk (T);
      end Queue_Partial_Error;
   begin
      if not T.Kitty_Chunk_Active then
         if Control.Valid and then Control.More_Specified and then Control.More
         then
            if Control.Transmission in 'f' | 't' | 's'
              or else Data_Length > 4_096
              or else Data_Length mod 4 /= 0
            then
               Queue_Current (Payload, Invalid => True);
               return;
            end if;

            if Control.Data_First = 0 then
               --  Some real clients (notably Chafa) send a metadata-only
               --  first chunk and begin the base64 data in the next APC.
               --  Preserve the separator needed by the assembled command.
               declare
                  Normalized : String := Payload & ";";
               begin
                  Normalized (Control.More_Value_Index) := '0';
                  if not Append_Kitty_Chunk_Data (T, Normalized) then
                     Queue_Current (Payload, Invalid => True);
                     Clear_Kitty_Chunk (T);
                     return;
                  end if;
               end;
            else
               declare
                  Normalized : String := Payload;
               begin
                  Normalized (Control.More_Value_Index) := '0';
                  if not Append_Kitty_Chunk_Data (T, Normalized) then
                     Queue_Current (Payload, Invalid => True);
                     Clear_Kitty_Chunk (T);
                     return;
                  end if;
               end;
            end if;
            T.Kitty_Chunk_Active := True;
            T.Kitty_Chunk_Action := Control.Action;
            --  A partial transaction is not a renderable graphics event.  In
            --  particular, do not leave the legacy snapshot pointing at an
            --  older command while the core waits for the final chunk.
            T.Last_Graphics.Pending := False;
            T.Kitty_Chunk_Blocks_Input :=
              (not Control.Quiet_Specified or else Control.Quiet /= 2)
              or else
                (Control.Action in 'T' | 'p'
                 and then Kitty_Field_Value (Payload, 'C') /= "1"
                 and then Kitty_Field_Value (Payload, 'U') /= "1"
                 and then
                   (Kitty_Field_Value (Payload, 'P')'Length = 0
                    or else Kitty_Field_Value (Payload, 'P') = "0"));
            return;
         end if;

         Queue_Current
           (Payload,
            Invalid =>
              (Control.More_Specified and then not Control.Valid));
         return;
      end if;

      --  A delete command is explicitly allowed to cancel a partial upload.
      if not Control.Valid
        and then Kitty_Field_Value (Payload, 'a') = "d"
        and then Data_Length = 0
      then
         Advance_Graphics_Transaction (T);
         Clear_Kitty_Chunk (T);
         Queue_Current (Payload);
         return;
      end if;

      if not Control.Valid
        or else Data_Length > 4_096
        or else (Control.More and then Data_Length mod 4 /= 0)
      then
         Queue_Partial_Error;
         return;
      end if;

      if Data_Length > 0
        and then not Append_Kitty_Chunk_Data
          (T, Payload (Control.Data_First .. Payload'Last))
      then
         Queue_Partial_Error;
         return;
      end if;

      if Control.Quiet_Specified then
         if not Apply_Kitty_Chunk_Quiet (T, Control.Quiet) then
            Queue_Partial_Error;
            return;
         end if;
         T.Kitty_Chunk_Blocks_Input :=
           Control.Quiet /= 2
           or else
             (T.Kitty_Chunk_Action in 'T' | 'p'
              and then
                Kitty_Field_Value
                  (T.Kitty_Chunk_Data (1 .. T.Kitty_Chunk_Length), 'C') /= "1"
              and then
                Kitty_Field_Value
                  (T.Kitty_Chunk_Data (1 .. T.Kitty_Chunk_Length), 'U') /= "1"
              and then
                (Kitty_Field_Value
                   (T.Kitty_Chunk_Data (1 .. T.Kitty_Chunk_Length), 'P')'Length = 0
                 or else Kitty_Field_Value
                   (T.Kitty_Chunk_Data (1 .. T.Kitty_Chunk_Length), 'P') = "0"));
      end if;

      if Control.More then
         T.Last_Graphics.Pending := False;
         return;
      end if;

      Queue_Current
        (T.Kitty_Chunk_Data (1 .. T.Kitty_Chunk_Length));
      Clear_Kitty_Chunk (T);
   end Process_Kitty_Graphics_APC;

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
         Sixel_Scrolls_Right      => False);

   end Default_Modes;

   procedure Reset_Terminal (T : in out Terminal) is
   begin
      Clear_Graphics_Transfer (T);
      Clear_ITerm2_Multipart (T);
      Clear_Graphics_Events (T);
      Advance_Graphics_Transaction (T);
      Clear_Deferred_Input (T);
      T.Primary_Graphics_Generation :=
        T.Primary_Graphics_Generation + 1;
      if T.Primary_Graphics_Generation = 0 then
         T.Primary_Graphics_Generation := 1;
      end if;
      T.Alternate_Graphics_Generation :=
        T.Alternate_Graphics_Generation + 1;
      if T.Alternate_Graphics_Generation = 0 then
         T.Alternate_Graphics_Generation := 1;
      end if;
      Reset_Graphics_Scroll (T, False);
      Reset_Graphics_Scroll (T, True);
      T.Active := Primary;
      T.Current_Modes := Default_Modes;
      T.Cursor_Row := 1;
      T.Cursor_Col := 1;
      T.Current_Cursor_Shape := Cursor_Block;
      T.Current_Cursor_Blinking := False;
      T.Saved_Row := 1;
      T.Saved_Col := 1;
      T.Pending_Wrap := False;
      T.Top_Margin := 1;
      T.Bottom_Margin := T.Rows;
      T.Scrollback_Rows := 0;
      T.Current_Style := (others => <>);
      T.Saved_Style := (others => <>);
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
      T.Last_Printable := 0;
      T.Has_Last_Printable := False;
      T.Window_Title := (others => <>);
      T.Saved_Window_Title := (others => <>);
      T.Saved_Window_Title_Valid := False;
      T.Clipboard_Data := (others => <>);
      T.Current_Link := (others => <>);
      T.Response_Length := 0;
      T.State := Ground;
      T.CSI_Private := ASCII.NUL;
      T.CSI_Params := (others => 0);
      T.CSI_Set := (others => False);
      T.CSI_Separators := (others => ASCII.NUL);
      T.CSI_Count := 0;
      T.CSI_Intermediates := (others => ASCII.NUL);
      T.CSI_Intermediate_Count := 0;
      T.OSC_Count := 0;
      T.Ignored_String_Data := (others => ASCII.NUL);
      T.Ignored_String_Count := 0;
      T.Ignored_String_Is_DCS := False;
      T.Ignored_String_Is_APC := False;
      T.UTF8_Need := 0;
      T.UTF8_Seen := 0;
      T.UTF8_Accum := 0;
      T.UTF8_Min := 0;
      Reset_Tab_Stops (T);
      Reset_Buffer (T, T.Primary_Cells);
      Reset_Buffer (T, T.Alt_Cells);
   end Reset_Terminal;

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
      when Storage_Error =>
         Status := False;
   end Allocate_Buffers;

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
      if Rows = 0 or else Cols = 0 then
         Status := Invalid_Size;
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

   procedure Finish_OSC (T : in out Terminal) is
      Command : Natural := 0;
      Payload_First : Natural := 0;
      Title_Length : Natural;

      function Payload_Starts_With (Text : String) return Boolean is
      begin
         if Payload_First = 0
           or else T.OSC_Count - Payload_First + 1 < Text'Length
         then
            return False;
         end if;

         for I in Text'Range loop
            if T.OSC_Data (Payload_First + I - Text'First) /= Text (I) then
               return False;
            end if;
         end loop;
         return True;
      end Payload_Starts_With;

      function Base64_Value (Ch : Standard.Character) return Integer is
      begin
         case Ch is
            when 'A' .. 'Z' =>
               return Standard.Character'Pos (Ch) - Standard.Character'Pos ('A');
            when 'a' .. 'z' =>
               return 26 + Standard.Character'Pos (Ch) - Standard.Character'Pos ('a');
            when '0' .. '9' =>
               return 52 + Standard.Character'Pos (Ch) - Standard.Character'Pos ('0');
            when '+' =>
               return 62;
            when '/' =>
               return 63;
            when others =>
               return -1;
         end case;
      end Base64_Value;

      procedure Decode_OSC52
        (First : Natural;
         Last  : Natural)
      is
         Enc_First : Natural := 0;
         Out_Len   : Natural := 0;
         Bits      : Natural := 0;
         Bit_Count : Natural := 0;
         Invalid   : Boolean := False;
         Done      : Boolean := False;
         Target    : Clipboard_Target := Clipboard_Clipboard;

         function Parse_Target return Boolean is
            Saw_Supported : Boolean := False;
         begin
            if Enc_First <= First + 1 then
               return True;
            end if;

            for I in First .. Enc_First - 2 loop
               case T.OSC_Data (I) is
                  when 'c' =>
                     Target := Clipboard_Clipboard;
                     Saw_Supported := True;
                  when 'p' =>
                     if not Saw_Supported then
                        Target := Clipboard_Primary;
                     end if;
                     Saw_Supported := True;
                  when 's' =>
                     if not Saw_Supported then
                        Target := Clipboard_Selection;
                     end if;
                     Saw_Supported := True;
                  when others =>
                     return False;
               end case;
            end loop;

            return Saw_Supported;
         end Parse_Target;

         procedure Append_Decoded (Value : Natural) is
         begin
            if Out_Len >= Max_Clipboard_Length then
               T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
               Invalid := True;
            else
               Out_Len := Out_Len + 1;
               T.Clipboard_Data.Text (Out_Len) :=
                 Standard.Character'Val (Value);
            end if;
         end Append_Decoded;
      begin
         for I in First .. Last loop
            if T.OSC_Data (I) = ';' then
               Enc_First := I + 1;
               exit;
            end if;
         end loop;

         if Enc_First = 0 then
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            return;
         end if;

         T.Clipboard_Data := (others => <>);
         if not Parse_Target then
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            return;
         end if;

         if Enc_First = Last and then T.OSC_Data (Enc_First) = '?' then
            T.Clipboard_Data.Pending := True;
            T.Clipboard_Data.Operation := Clipboard_Query;
            T.Clipboard_Data.Target := Target;
            return;
         end if;

         if Enc_First <= Last then
            for I in Enc_First .. Last loop
               declare
                  Ch : constant Standard.Character := T.OSC_Data (I);
                  V  : constant Integer := Base64_Value (Ch);
               begin
                  if Ch = '=' then
                     Done := True;
                  elsif Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
                     null;
                  elsif Done or else V < 0 then
                     Invalid := True;
                  else
                     Bits := Bits * 64 + Natural (V);
                     Bit_Count := Bit_Count + 6;
                     while Bit_Count >= 8 loop
                        Bit_Count := Bit_Count - 8;
                        Append_Decoded ((Bits / (2 ** Bit_Count)) mod 256);
                     end loop;
                     if Bit_Count = 0 then
                        Bits := 0;
                     else
                        Bits := Bits mod (2 ** Bit_Count);
                     end if;
                  end if;
               end;

               exit when Invalid;
            end loop;
         end if;

         if Invalid then
            T.Clipboard_Data := (others => <>);
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         else
            T.Clipboard_Data.Pending := True;
            T.Clipboard_Data.Target := Target;
            T.Clipboard_Data.Length := Out_Len;
         end if;
      end Decode_OSC52;

      procedure Decode_OSC8
        (First : Natural;
         Last  : Natural)
      is
         URI_First : Natural := 0;
         Link      : Hyperlink;

         procedure Copy_URI (From : Natural; To : Natural) is
            Count : Natural := 0;
         begin
            if From > To then
               return;
            end if;

            for I in From .. To loop
               if Count < Max_Hyperlink_URI_Length then
                  Count := Count + 1;
                  Link.URI (Count) := T.OSC_Data (I);
               else
                  T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                  exit;
               end if;
            end loop;
            Link.URI_Length := Count;
         end Copy_URI;

         procedure Copy_ID (From : Natural; To : Natural) is
            Count : Natural := 0;
         begin
            if From > To then
               return;
            end if;

            for I in From .. To loop
               if Count < Max_Hyperlink_ID_Length then
                  Count := Count + 1;
                  Link.ID (Count) := T.OSC_Data (I);
               else
                  T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                  exit;
               end if;
            end loop;
            Link.ID_Length := Count;
         end Copy_ID;

         procedure Parse_Params (From : Natural; To : Natural) is
            I : Natural := From;
            Param_Start : Natural;
            Param_End   : Natural;
         begin
            if From > To then
               return;
            end if;

            while I <= To loop
               Param_Start := I;
               while I <= To and then T.OSC_Data (I) /= ':' loop
                  I := I + 1;
               end loop;
               Param_End := I - 1;
               if Param_End >= Param_Start + 3
                 and then T.OSC_Data (Param_Start) = 'i'
                 and then T.OSC_Data (Param_Start + 1) = 'd'
                 and then T.OSC_Data (Param_Start + 2) = '='
               then
                  Copy_ID (Param_Start + 3, Param_End);
               end if;
               I := I + 1;
            end loop;
         end Parse_Params;
      begin
         for I in First .. Last loop
            if T.OSC_Data (I) = ';' then
               URI_First := I + 1;
               exit;
            end if;
         end loop;

         if URI_First = 0 then
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            return;
         elsif URI_First > Last then
            T.Current_Link := (others => <>);
            return;
         end if;

         Link := (others => <>);
         Link.Active := True;
         Parse_Params (First, URI_First - 2);
         Copy_URI (URI_First, Last);

         if Link.URI_Length = 0 then
            T.Current_Link := (others => <>);
         else
            T.Current_Link := Link;
         end if;
      end Decode_OSC8;
   begin
      if T.OSC_Count < 3 then
         T.State := Ground;
         return;
      end if;

      for I in 1 .. T.OSC_Count loop
         if T.OSC_Data (I) = ';' then
            Payload_First := I + 1;
            exit;
         elsif T.OSC_Data (I) in '0' .. '9' then
            Command :=
              Natural'Min
                (Command * 10
                 + Standard.Character'Pos (T.OSC_Data (I))
                 - Standard.Character'Pos ('0'),
                 Natural'Last / 2);
         else
            T.State := Ground;
            return;
         end if;
      end loop;

      if Payload_First = 0 then
         T.State := Ground;
         return;
      end if;

      if Command in 0 .. 2 then
         Title_Length :=
           Natural'Min
             (T.OSC_Count - Payload_First + 1,
              Max_Title_Length);
         T.Window_Title := (others => <>);
         T.Window_Title.Length := Title_Length;
         for I in 1 .. Title_Length loop
            T.Window_Title.Text (I) := T.OSC_Data (Payload_First + I - 1);
         end loop;
      elsif Command = 8 then
         Decode_OSC8 (Payload_First, T.OSC_Count);
      elsif Command = 52 then
         Decode_OSC52 (Payload_First, T.OSC_Count);
      elsif Command = 1337
        and then T.OSC_Count - Payload_First + 1 = 12
        and then OSC_Slice (T, Payload_First, T.OSC_Count) = "Capabilities"
      then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_String (T, "]1337;Capabilities=");
         if T.Graphics_Capabilities.ITerm2_Inline_Images
           and then T.Graphics_Capabilities.ITerm2_File_Downloads
         then
            Append_Response_Char (T, 'F');
         end if;
         if T.Graphics_Capabilities.Sixel then
            Append_Response_String (T, "Sx");
         end if;
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '\');
      elsif Command = 1337 and then Payload_Starts_With ("File=") then
         Note_Graphics_Protocol
           (T,
            Graphics_ITerm2,
            T.OSC_Count - Payload_First + 1,
            OSC_Slice (T, Payload_First, T.OSC_Count));
      elsif Command = 1337
        and then Payload_Starts_With ("MultipartFile=")
      then
         Clear_ITerm2_Multipart (T);
         T.ITerm2_Multipart_Active := True;
         declare
            Accepted : Boolean := Append_ITerm2_Multipart (T, "File=");
         begin
            if Accepted and then Payload_First + 14 <= T.OSC_Count then
               Accepted := Append_ITerm2_Multipart
                 (T, OSC_Slice (T, Payload_First + 14, T.OSC_Count));
            end if;
            if Accepted then
               Accepted := Append_ITerm2_Multipart (T, ":");
            end if;
            if not Accepted then
               Clear_ITerm2_Multipart (T);
            end if;
         end;
      elsif Command = 1337
        and then Payload_Starts_With ("FilePart=")
        and then T.ITerm2_Multipart_Active
      then
         declare
            Accepted : Boolean := True;
         begin
            if Payload_First + 9 <= T.OSC_Count then
               Accepted := Append_ITerm2_Multipart
                 (T, OSC_Slice (T, Payload_First + 9, T.OSC_Count));
            end if;
            if not Accepted then
               Clear_ITerm2_Multipart (T);
            end if;
         end;
      elsif Command = 1337
        and then T.ITerm2_Multipart_Active
        and then T.OSC_Count - Payload_First + 1 = 7
        and then OSC_Slice (T, Payload_First, T.OSC_Count) = "FileEnd"
      then
         if T.ITerm2_Multipart /= null
           and then T.ITerm2_Multipart_Length > 6
         then
            Note_Graphics_Protocol
              (T,
               Graphics_ITerm2,
               T.ITerm2_Multipart_Length,
               T.ITerm2_Multipart (1 .. T.ITerm2_Multipart_Length));
         end if;
         Clear_ITerm2_Multipart (T);
      end if;

      T.State := Ground;
   end Finish_OSC;

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
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      Low_ID : Graphics_ID;
      Placement_Valid : Boolean;
      Image_Valid : Boolean;
      Values : array (Positive range 1 .. 3) of Natural := (others => 0);
      Decoded_Count : Natural := 0;
      High_Value : Natural := 0;
      Col : Positive;
   begin
      if Cells = null or else Cell_Index not in Cells'Range then
         return;
      end if;

      Cells (Cell_Index).Image := (others => <>);
      if Cells (Cell_Index).Kind /= Character
        or else Cells (Cell_Index).Text.Code_Point /= Kitty_Image_Placeholder
      then
         return;
      end if;

      Cells (Cell_Index).Image.Is_Placeholder := True;
      Low_ID :=
        Color_Graphics_ID (Cells (Cell_Index).Style.Foreground, Image_Valid);
      Cells (Cell_Index).Image.Image_ID_Valid := Image_Valid;
      Cells (Cell_Index).Image.Placement_ID :=
        Color_Graphics_ID
          (Cells (Cell_Index).Style.Underline_Color, Placement_Valid);

      for I in 1 .. Natural'Min
        (Cells (Cell_Index).Text.Attachment_Count, Values'Length)
      loop
         exit when not Image_Diacritic_Value
           (Cells (Cell_Index).Text.Attachments (I), Values (I));
         Decoded_Count := I;
      end loop;

      if Decoded_Count >= 1 then
         Cells (Cell_Index).Image.Image_Row := Values (1);
         Cells (Cell_Index).Image.Row_Specified := True;
      end if;
      if Decoded_Count >= 2 then
         Cells (Cell_Index).Image.Image_Column := Values (2);
         Cells (Cell_Index).Image.Column_Specified := True;
      end if;
      if Decoded_Count >= 3 and then Values (3) <= 255 then
         High_Value := Values (3);
         Cells (Cell_Index).Image.High_Byte_Specified := True;
      elsif Decoded_Count >= 3 then
         Cells (Cell_Index).Image.Image_ID_Valid := False;
      end if;

      Col := Positive (((Cell_Index - 1) mod T.Cols) + 1);
      if Col > 1 then
         declare
            Left : Cell renames Cells (Cell_Index - 1);
            Same_Colors : constant Boolean :=
              Left.Image.Is_Placeholder
              and then Left.Style.Foreground =
                Cells (Cell_Index).Style.Foreground
              and then Left.Style.Underline_Color =
                Cells (Cell_Index).Style.Underline_Color;
            Left_High : constant Natural :=
              Natural (Left.Image.Image_ID / Graphics_ID (16#1_000000#));
         begin
            if Same_Colors and then Decoded_Count = 0 then
               Cells (Cell_Index).Image.Image_Row := Left.Image.Image_Row;
               Cells (Cell_Index).Image.Image_Column :=
                 Left.Image.Image_Column + 1;
               High_Value := Left_High;
            elsif Same_Colors
              and then Decoded_Count = 1
              and then Values (1) = Left.Image.Image_Row
            then
               Cells (Cell_Index).Image.Image_Column :=
                 Left.Image.Image_Column + 1;
               High_Value := Left_High;
            elsif Same_Colors
              and then Decoded_Count = 2
              and then Values (1) = Left.Image.Image_Row
              and then Values (2) = Left.Image.Image_Column + 1
            then
               High_Value := Left_High;
            end if;
         end;
      end if;

      Cells (Cell_Index).Image.Image_ID :=
        Low_ID + Graphics_ID (High_Value) * Graphics_ID (16#1_000000#);
      Cells (Cell_Index).Image.Image_ID_Valid :=
        Cells (Cell_Index).Image.Image_ID_Valid
        and then Cells (Cell_Index).Image.Image_ID /= 0;
   end Decode_Image_Cell;

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

   procedure Put_Code_Point (T : in out Terminal; CP : Common.Code_Point) is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      W     : constant Cell_Width :=
        (if Is_Zero_Width (CP) then Width_Zero
         elsif Is_Wide (CP) then Width_Two
         else Width_One);

      function Previous_Cell_Index return Natural is
         Row : constant Positive := T.Cursor_Row;
         Col : Natural;
      begin
         if T.Pending_Wrap then
            Col := T.Cursor_Col;
         elsif T.Cursor_Col > 1 then
            Col := T.Cursor_Col - 1;
         else
            return 0;
         end if;

         if Cells (Index (T, Row, Positive (Col))).Kind = Wide_Continuation
           and then Col > 1
         then
            Col := Col - 1;
         end if;

         return Index (T, Row, Positive (Col));
      end Previous_Cell_Index;

      function Attach_To_Previous_Cell
        (Attached_CP : Common.Code_Point) return Boolean
      is
         Cell_Index : constant Natural := Previous_Cell_Index;

         function Should_Promote_To_Emoji_Width return Boolean is
         begin
            return
              (Attached_CP = 16#FE0F#
               and then Is_Emoji_Variation_Base
                 (Cells (Cell_Index).Text.Code_Point))
              or else
                (Attached_CP = 16#20E3#
                 and then Is_Keycap_Base
                   (Cells (Cell_Index).Text.Code_Point));
         end Should_Promote_To_Emoji_Width;

         procedure Promote_Emoji_Width is
            Col : constant Positive :=
              Positive (((Cell_Index - 1) mod T.Cols) + 1);
            Next_Col : constant Positive := Col + 1;
         begin
            if Col = T.Cols
              or else Cells (Cell_Index).Text.Width /= Width_One
              or else not Should_Promote_To_Emoji_Width
            then
               return;
            end if;

            Clear_Wide_Overlap (T, T.Cursor_Row, Next_Col, Width_One);
            Cells (Cell_Index).Text.Width := Width_Two;
            Cells (Index (T, T.Cursor_Row, Next_Col)) :=
              (Kind  => Wide_Continuation,
               Text  => (Code_Point => 0,
                         Width      => Width_Zero,
                         others     => <>),
               Style => Cells (Cell_Index).Style,
               Link  => Cells (Cell_Index).Link,
               Image => <>);

            if T.Cursor_Col = Next_Col then
               if Next_Col = T.Cols then
                  T.Pending_Wrap := True;
               else
                  T.Cursor_Col := Next_Col + 1;
                  T.Pending_Wrap := False;
               end if;
            end if;
         end Promote_Emoji_Width;
      begin
         if Cell_Index = 0 then
            return False;
         end if;

         if Cells (Cell_Index).Kind /= Character
           or else Cells (Cell_Index).Text.Code_Point = 0
         then
            return False;
         end if;

         if Cells (Cell_Index).Text.Attachment_Count <
           Max_Cluster_Attachments
         then
            Cells (Cell_Index).Text.Attachment_Count :=
              Cells (Cell_Index).Text.Attachment_Count + 1;
            Cells (Cell_Index).Text.Attachments
              (Cells (Cell_Index).Text.Attachment_Count) := Attached_CP;
            Decode_Image_Cell (T, Positive (Cell_Index));
            Promote_Emoji_Width;
            Mark_Dirty (T, T.Cursor_Row);
            return True;
         else
            T.Diag.Text_Cluster_Overflow := T.Diag.Text_Cluster_Overflow + 1;
            return False;
         end if;
      end Attach_To_Previous_Cell;

      function Previous_Cluster_Accepts_Spacing
        (Spacing_CP : Common.Code_Point) return Boolean
      is
         Cell_Index : constant Natural := Previous_Cell_Index;
         Count      : Cluster_Attachment_Count;
      begin
         if Cell_Index = 0
           or else Cells (Cell_Index).Kind /= Character
         then
            return False;
         end if;

         Count := Cells (Cell_Index).Text.Attachment_Count;
         return
           (Count > 0
            and then Cells (Cell_Index).Text.Attachments (Count) = 16#200D#)
           or else
             (Count = 0
              and then Is_Regional_Indicator
                (Cells (Cell_Index).Text.Code_Point)
              and then Is_Regional_Indicator (Spacing_CP))
           or else
             (Is_Emoji_Modifier (Spacing_CP)
              and then Cells (Cell_Index).Text.Width = Width_Two
              and then Is_Wide (Cells (Cell_Index).Text.Code_Point)
              and then not Is_Regional_Indicator
                (Cells (Cell_Index).Text.Code_Point));
      end Previous_Cluster_Accepts_Spacing;
   begin
      if Cells = null then
         return;
      elsif W = Width_Zero then
         if not Attach_To_Previous_Cell (CP) then
            null;
         end if;
         return;
      elsif Previous_Cluster_Accepts_Spacing (CP) then
         if not Attach_To_Previous_Cell (CP) then
            null;
         end if;
         return;
      end if;

      if T.Pending_Wrap then
         T.Cursor_Col := 1;
         New_Line (T);
      end if;

      if W = Width_Two and then T.Cursor_Col = T.Cols then
         T.Cursor_Col := 1;
         New_Line (T);
      end if;

      if T.Current_Modes.Insert_Mode then
         Shift_Row_Right
           (T,
            T.Cursor_Row,
            T.Cursor_Col,
            (if W = Width_Two then 2 else 1));
      else
         Clear_Wide_Overlap (T, T.Cursor_Row, T.Cursor_Col, W);
      end if;

      Cells (Index (T, T.Cursor_Row, T.Cursor_Col)) :=
        (Kind  => Character,
         Text  => (Code_Point => CP, Width => W, others => <>),
         Style => T.Current_Style,
         Link  => T.Current_Link,
         Image => <>);
      Decode_Image_Cell (T, Index (T, T.Cursor_Row, T.Cursor_Col));
      T.Last_Printable := CP;
      T.Has_Last_Printable := True;
      Mark_Dirty (T, T.Cursor_Row);

      if W = Width_Two then
         if T.Cursor_Col < T.Cols then
            Cells (Index (T, T.Cursor_Row, T.Cursor_Col + 1)) :=
              (Kind => Wide_Continuation,
               Text => (Code_Point => 0, Width => Width_Zero, others => <>),
               Style => T.Current_Style,
               Link  => T.Current_Link,
               Image => <>);
         end if;
         if T.Cursor_Col + 1 >= T.Cols then
            T.Cursor_Col := T.Cols;
            T.Pending_Wrap := T.Current_Modes.Autowrap;
         else
            T.Cursor_Col := T.Cursor_Col + 2;
         end if;
      elsif T.Cursor_Col = T.Cols then
         T.Pending_Wrap := T.Current_Modes.Autowrap;
      else
         T.Cursor_Col := T.Cursor_Col + 1;
      end if;
   end Put_Code_Point;

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
      if T.Response_Length < Max_Response_Length then
         T.Response_Length := T.Response_Length + 1;
         T.Responses (T.Response_Length) := B;
      else
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
      end if;
   end Append_Response_Byte;

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

   procedure Finish_Ignored_String (T : in out Terminal) is
      function Finish_Tmux_Passthrough return Boolean is
         Prefix : constant String := "tmux;";
         Decoded : Core_Byte_Array_Access := null;
         Decoded_Count : Natural := 0;
         I : Natural;
         Status : Feed_Status;
      begin
         if not T.Ignored_String_Is_DCS
           or else T.Graphics_Transfer = null
           or else T.Graphics_Transfer_Length <= Prefix'Length
         then
            return False;
         end if;

         for J in Prefix'Range loop
            if T.Graphics_Transfer (J) /= Prefix (J) then
               return False;
            end if;
         end loop;

         begin
            Decoded :=
              new Core_Byte_Array
                (1 .. T.Graphics_Transfer_Length - Prefix'Length);
         exception
            when Storage_Error =>
               T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
               return True;
         end;

         I := Prefix'Length + 1;
         while I <= T.Graphics_Transfer_Length loop
            if T.Graphics_Transfer (I) = ASCII.ESC
              and then I < T.Graphics_Transfer_Length
              and then T.Graphics_Transfer (I + 1) = ASCII.ESC
            then
               Decoded_Count := Decoded_Count + 1;
               Decoded.all (Decoded_Count) := 16#1B#;
               I := I + 2;
            else
               Decoded_Count := Decoded_Count + 1;
               Decoded.all (Decoded_Count) :=
                 Common.Bytes.Byte
                   (Standard.Character'Pos (T.Graphics_Transfer (I)));
               I := I + 1;
            end if;
         end loop;

         T.Ignored_String_Is_DCS := False;
         T.Ignored_String_Is_APC := False;
         T.State := Ground;
         T.Diag.Multiplexer_Passthrough :=
           T.Diag.Multiplexer_Passthrough + 1;
         Clear_Graphics_Transfer (T);

         if Decoded_Count > 0 then
            Feed (T, Decoded.all (1 .. Decoded_Count), Status);
         end if;
         Free_Deferred_Input (Decoded);

         return True;
      exception
         when others =>
            if Decoded /= null then
               Free_Deferred_Input (Decoded);
            end if;
            raise;
      end Finish_Tmux_Passthrough;

      function Cursor_Style_Param return Natural is
      begin
         case T.Current_Cursor_Shape is
            when Cursor_Block =>
               return (if T.Current_Cursor_Blinking then 1 else 2);
            when Cursor_Underline =>
               return (if T.Current_Cursor_Blinking then 3 else 4);
            when Cursor_Bar =>
               return (if T.Current_Cursor_Blinking then 5 else 6);
         end case;
      end Cursor_Style_Param;

      function Is_Sixel_DCS return Boolean is
         I : Natural := 1;
      begin
         if not T.Ignored_String_Is_DCS
           or else T.Graphics_Transfer = null
           or else T.Graphics_Transfer_Length = 0
         then
            return False;
         end if;

         while I <= T.Graphics_Transfer_Length loop
            case T.Graphics_Transfer (I) is
               when '0' .. '9' | ';' | '?' =>
                  I := I + 1;
               when 'q' =>
                  return True;
               when others =>
                  return False;
            end case;
         end loop;

         return False;
      end Is_Sixel_DCS;

      type Sixel_Extent is record
         Width  : Natural := 0;
         Height : Natural := 0;
      end record;

      function Measure_Sixel return Sixel_Extent is
         I : Natural := 1;
         X : Natural := 0;
         Y : Natural := 0;
         Max_X : Natural := 0;
         Max_Y : Natural := 0;
         Repeat_Count : Natural := 1;
         Declared_Width : Natural := 0;
         Declared_Height : Natural := 0;
         Vertical_Aspect : Positive := 1;
         Q_Position : Natural := 0;

         function Read_Number return Natural is
            Value : Natural := 0;
         begin
            while I <= T.Graphics_Transfer_Length
              and then T.Graphics_Transfer (I) in '0' .. '9'
            loop
               declare
                  Digit : constant Natural :=
                    Standard.Character'Pos (T.Graphics_Transfer (I))
                    - Standard.Character'Pos ('0');
               begin
                  if Value > (Natural'Last - Digit) / 10 then
                     Value := Natural'Last;
                  else
                     Value := Value * 10 + Digit;
                  end if;
               end;
               I := I + 1;
            end loop;
            return Value;
         end Read_Number;

         procedure Skip_Number is
            Ignored : constant Natural := Read_Number;
            pragma Unreferenced (Ignored);
         begin
            null;
         end Skip_Number;

         procedure Add_X (Amount : Natural) is
         begin
            if X > Natural'Last - Amount then
               X := Natural'Last;
            else
               X := X + Amount;
            end if;
         end Add_X;
      begin
         while I <= T.Graphics_Transfer_Length
           and then T.Graphics_Transfer (I) /= 'q'
         loop
            I := I + 1;
         end loop;
         if I > T.Graphics_Transfer_Length then
            return (others => 0);
         end if;
         Q_Position := I;
         if T.Graphics_Transfer (1) in '0' .. '9' then
            I := 1;
            declare
               Aspect_Code : constant Natural := Read_Number;
            begin
               Vertical_Aspect :=
                 (case Aspect_Code is
                     when 0 | 1 | 5 | 6 => 2,
                     when 2 => 5,
                     when 3 | 4 => 3,
                     when others => 1);
            end;
         end if;
         I := Q_Position + 1;

         while I <= T.Graphics_Transfer_Length loop
            case T.Graphics_Transfer (I) is
               when '!' =>
                  I := I + 1;
                  Repeat_Count := Natural'Max (1, Read_Number);
               when '#' =>
                  I := I + 1;
                  Skip_Number;
                  while I <= T.Graphics_Transfer_Length
                    and then T.Graphics_Transfer (I) = ';'
                  loop
                     I := I + 1;
                     Skip_Number;
                  end loop;
               when '"' =>
                  I := I + 1;
                  declare
                     Pan : constant Natural := Read_Number;
                     Pad : Natural := 0;
                  begin
                     if I <= T.Graphics_Transfer_Length
                       and then T.Graphics_Transfer (I) = ';'
                     then
                        I := I + 1;
                        Pad := Read_Number;
                     end if;
                     if Pan > 0 and then Pad > 0 then
                        declare
                           Ratio : constant Natural :=
                             Pan / Pad
                             + (if Pan mod Pad = 0 then 0 else 1);
                        begin
                           Vertical_Aspect :=
                             Positive (Natural'Max (Ratio, 1));
                        end;
                     end if;
                  end;
                  if I <= T.Graphics_Transfer_Length
                    and then T.Graphics_Transfer (I) = ';'
                  then
                     I := I + 1;
                     Declared_Width := Read_Number;
                  end if;
                  if I <= T.Graphics_Transfer_Length
                    and then T.Graphics_Transfer (I) = ';'
                  then
                     I := I + 1;
                     Declared_Height := Read_Number;
                  end if;
               when '$' =>
                  X := 0;
                  I := I + 1;
               when '-' =>
                  X := 0;
                  if Y > Natural'Last - 6 then
                     Y := Natural'Last;
                  else
                     Y := Y + 6;
                  end if;
                  I := I + 1;
               when '?' .. '~' =>
                  Add_X (Repeat_Count);
                  Max_X := Natural'Max (Max_X, X);
                  Max_Y :=
                    Natural'Max
                      (Max_Y,
                       (if Y > Natural'Last - 6
                        then Natural'Last else Y + 6));
                  Repeat_Count := 1;
                  I := I + 1;
               when others =>
                  Repeat_Count := 1;
                  I := I + 1;
            end case;
         end loop;
         declare
            Logical_Height : constant Natural :=
              Natural'Max (Max_Y, Declared_Height);
         begin
            return
              (Width  => Natural'Max (Max_X, Declared_Width),
               Height =>
                 (if Logical_Height > Natural'Last / Vertical_Aspect
                  then Natural'Last
                  else Logical_Height * Vertical_Aspect));
         end;
      end Measure_Sixel;

      function Is_Kitty_Graphics_APC return Boolean is
      begin
         return T.Ignored_String_Is_APC
           and then T.Graphics_Transfer_Length >= 1
           and then T.Graphics_Transfer /= null
           and then T.Graphics_Transfer (1) = 'G';
      end Is_Kitty_Graphics_APC;

   begin
      if Finish_Tmux_Passthrough then
         Clear_Graphics_Transfer (T);
         return;
      end if;

      if T.Kitty_Chunk_Active and then not Is_Kitty_Graphics_APC then
         Reject_Kitty_Chunk_Interleave (T);
      end if;

      if Is_Sixel_DCS then
         declare
            Extent : constant Sixel_Extent := Measure_Sixel;
            At_Row : constant Positive :=
              (if T.Current_Modes.Sixel_Display_Mode then 1
               else T.Cursor_Row);
            At_Col : constant Positive :=
              (if T.Current_Modes.Sixel_Display_Mode then 1
               else T.Cursor_Col);
         begin
            Note_Graphics_Protocol
              (T,
               Graphics_Sixel,
               T.Graphics_Transfer_Length,
               T.Graphics_Transfer (1 .. T.Graphics_Transfer_Length),
               At_Row => At_Row,
               At_Col => At_Col);

            if not T.Current_Modes.Sixel_Display_Mode then
               if T.Current_Modes.Sixel_Scrolls_Right
                 and then T.Cell_Pixel_Width > 0
                 and then Extent.Width > 0
                 and then
                   Extent.Width <= T.Graphics_Limits.Pixel_Dimension
               then
                  declare
                     Cells_Wide : constant Natural :=
                       1 + (Extent.Width - 1) / T.Cell_Pixel_Width;
                  begin
                     T.Cursor_Col :=
                       (if Cells_Wide >= T.Cols - T.Cursor_Col
                        then T.Cols
                        else T.Cursor_Col + Positive (Cells_Wide));
                     Mark_Cursor_Move (T, T.Cursor_Row);
                  end;
               elsif T.Cell_Pixel_Height > 0
                 and then Extent.Height > 0
                 and then
                   Extent.Height <= T.Graphics_Limits.Pixel_Dimension
               then
                  declare
                     Cell_Rows : constant Natural :=
                       1 + (Extent.Height - 1) / T.Cell_Pixel_Height;
                  begin
                     for Row in 1 .. Natural'Max (1, Cell_Rows) loop
                        New_Line (T);
                     end loop;
                  end;
               end if;
            end if;
         end;
      elsif Is_Kitty_Graphics_APC then
         declare
            Payload : String renames
              T.Graphics_Transfer (1 .. T.Graphics_Transfer_Length);
         begin
            Process_Kitty_Graphics_APC (T, Payload);
         end;
      elsif T.Ignored_String_Is_DCS
        and then T.Ignored_String_Count >= 2
        and then T.Ignored_String_Data (1) = '$'
        and then T.Ignored_String_Data (2) = 'q'
      then
         if T.Ignored_String_Count = 2 then
            Append_DECRQSS_Negative (T);
         elsif T.Ignored_String_Count = 4
           and then T.Ignored_String_Data (3) = ' '
           and then T.Ignored_String_Data (4) = 'q'
         then
            Append_DECRQSS_Start (T, Valid => True);
            Append_Response_Natural (T, Cursor_Style_Param);
            Append_Response_Char (T, ' ');
            Append_Response_Char (T, 'q');
            Append_DECRQSS_End (T);
         else
            case T.Ignored_String_Data (3) is
               when 'm' =>
                  if T.Ignored_String_Count = 3 then
                     Append_DECRQSS_Start (T, Valid => True);
                     Append_SGR_Status (T);
                     Append_DECRQSS_End (T);
                  else
                     Append_DECRQSS_Negative (T);
                  end if;
               when 'r' =>
                  if T.Ignored_String_Count = 3 then
                     Append_DECRQSS_Start (T, Valid => True);
                     Append_Response_Natural (T, T.Top_Margin);
                     Append_Response_Char (T, ';');
                     Append_Response_Natural (T, T.Bottom_Margin);
                     Append_Response_Char (T, 'r');
                     Append_DECRQSS_End (T);
                  else
                     Append_DECRQSS_Negative (T);
                  end if;
               when others =>
                  Append_DECRQSS_Negative (T);
            end case;
         end if;
      end if;

      T.Ignored_String_Is_DCS := False;
      T.Ignored_String_Is_APC := False;
      Clear_Graphics_Transfer (T);
      T.State := Ground;
   end Finish_Ignored_String;

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
            if not Valid_Report then
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
               return;
            end if;
            Append_Response_Char (T, ASCII.ESC);
            Append_Response_Char (T, '[');
            if T.CSI_Private = '?' then
               Append_Response_Char (T, '?');
            elsif T.CSI_Private /= ASCII.NUL then
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
               return;
            end if;
            Append_Response_Natural (T, T.Cursor_Row);
            Append_Response_Char (T, ';');
            Append_Response_Natural (T, T.Cursor_Col);
            Append_Response_Char (T, 'R');
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
   end Queue_Device_Status_Report;

   procedure Queue_Device_Attributes
     (T : in out Terminal)
   is
   begin
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

   procedure Set_Mode (T : in out Terminal; Number : Natural; Enable : Boolean) is
   begin
      case Number is
         when 1 =>
            T.Current_Modes.Application_Cursor := Enable;
         when 6 =>
            T.Current_Modes.Origin_Mode := Enable;
            Move_Cursor (T, 1, 1);
         when 7 =>
            T.Current_Modes.Autowrap := Enable;
         when 12 =>
            T.Current_Modes.Cursor_Blinking := Enable;
            T.Current_Cursor_Blinking := Enable;
            Mark_Dirty (T, T.Cursor_Row);
         when 25 =>
            if T.Current_Modes.Cursor_Visible /= Enable then
               Mark_Dirty (T, T.Cursor_Row);
               T.Current_Modes.Cursor_Visible := Enable;
            end if;
         when 66 =>
            T.Current_Modes.Application_Keypad := Enable;
         when 67 =>
            T.Current_Modes.Backarrow_Key_Backspace := Enable;
         when 80 =>
            T.Current_Modes.Sixel_Display_Mode := Enable;
         when 1000 =>
            T.Current_Modes.Mouse_Button := Enable;
            if Enable then
               T.Current_Modes.Mouse_Drag := False;
               T.Current_Modes.Mouse_Any_Event := False;
            end if;
         when 1002 =>
            T.Current_Modes.Mouse_Drag := Enable;
            if Enable then
               T.Current_Modes.Mouse_Button := False;
               T.Current_Modes.Mouse_Any_Event := False;
            end if;
         when 1003 =>
            T.Current_Modes.Mouse_Any_Event := Enable;
            if Enable then
               T.Current_Modes.Mouse_Button := False;
               T.Current_Modes.Mouse_Drag := False;
            end if;
         when 1004 =>
            T.Current_Modes.Focus_Reporting := Enable;
         when 1005 =>
            T.Current_Modes.Mouse_UTF8 := Enable;
         when 1006 =>
            T.Current_Modes.Mouse_SGR := Enable;
         when 1015 =>
            T.Current_Modes.Mouse_URXVT := Enable;
         when 1070 =>
            T.Current_Modes.Sixel_Private_Colors := Enable;
         when 47 | 1047 =>
            if Enable then
               T.Alternate_Graphics_Generation :=
                 T.Alternate_Graphics_Generation + 1;
               if T.Alternate_Graphics_Generation = 0 then
                  T.Alternate_Graphics_Generation := 1;
               end if;
            end if;
            T.Current_Modes.Alternate_Screen := Enable;
            T.Active := (if Enable then Alternate else Primary);
            T.Cursor_Row := 1;
            T.Cursor_Col := 1;
            T.Pending_Wrap := False;
            if Enable then
               Reset_Buffer (T, T.Alt_Cells);
            else
               Mark_All_Dirty (T);
            end if;
         when 1048 =>
            if Enable then
               Save_Cursor_State (T);
            else
               Restore_Cursor_State (T);
            end if;
            T.Pending_Wrap := False;
         when 1049 =>
            if Enable then
               Save_Cursor_State (T);
               T.Alternate_Graphics_Generation :=
                 T.Alternate_Graphics_Generation + 1;
               if T.Alternate_Graphics_Generation = 0 then
                  T.Alternate_Graphics_Generation := 1;
               end if;
            end if;
            T.Current_Modes.Alternate_Screen := Enable;
            T.Active := (if Enable then Alternate else Primary);
            if Enable then
               T.Cursor_Row := 1;
               T.Cursor_Col := 1;
            else
               Restore_Cursor_State (T);
            end if;
            T.Pending_Wrap := False;
            if Enable then
               Reset_Buffer (T, T.Alt_Cells);
            else
               Mark_All_Dirty (T);
            end if;
         when 2004 =>
            T.Current_Modes.Bracketed_Paste := Enable;
         when 2026 =>
            T.Current_Modes.Synchronized_Update := Enable;
         when 8452 =>
            T.Current_Modes.Sixel_Scrolls_Right := Enable;
         when others =>
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end case;
   end Set_Mode;

   procedure Apply_SGR (T : in out Terminal) is
      I : Natural := 1;
      P : Natural;
   begin
      if T.CSI_Count = 0 then
         T.Current_Style := (others => <>);
         return;
      end if;

      while I <= T.CSI_Count loop
         P := Param (T, I, 0);
         case P is
            when 0 =>
               T.Current_Style := (others => <>);
            when 1 =>
               T.Current_Style.Bold := True;
            when 2 =>
               T.Current_Style.Faint := True;
            when 3 =>
               T.Current_Style.Italic := True;
            when 4 =>
               if I + 1 <= T.CSI_Count
                 and then Param_Separator (T, I + 1) = ':'
               then
                  case Param (T, I + 1, 1) is
                     when 0 =>
                        T.Current_Style.Underline := False;
                        T.Current_Style.Underline_Kind := Underline_Single;
                     when 1 =>
                        T.Current_Style.Underline := True;
                        T.Current_Style.Underline_Kind := Underline_Single;
                     when 2 =>
                        T.Current_Style.Underline := True;
                        T.Current_Style.Underline_Kind := Underline_Double;
                     when 3 =>
                        T.Current_Style.Underline := True;
                        T.Current_Style.Underline_Kind := Underline_Curly;
                     when 4 =>
                        T.Current_Style.Underline := True;
                        T.Current_Style.Underline_Kind := Underline_Dotted;
                     when 5 =>
                        T.Current_Style.Underline := True;
                        T.Current_Style.Underline_Kind := Underline_Dashed;
                     when others =>
                        T.Diag.Unsupported_Sequence :=
                          T.Diag.Unsupported_Sequence + 1;
                  end case;
                  I := I + 1;
               else
                  T.Current_Style.Underline := True;
                  T.Current_Style.Underline_Kind := Underline_Single;
               end if;
            when 5 | 6 =>
               T.Current_Style.Blink := True;
            when 7 =>
               T.Current_Style.Inverse := True;
            when 8 =>
               T.Current_Style.Conceal := True;
            when 9 =>
               T.Current_Style.Strikethrough := True;
            when 10 .. 19 =>
               null;
            when 21 =>
               T.Current_Style.Bold := False;
            when 22 =>
               T.Current_Style.Bold := False;
               T.Current_Style.Faint := False;
            when 23 =>
               T.Current_Style.Italic := False;
            when 24 =>
               T.Current_Style.Underline := False;
               T.Current_Style.Underline_Kind := Underline_Single;
            when 25 =>
               T.Current_Style.Blink := False;
            when 27 =>
               T.Current_Style.Inverse := False;
            when 28 =>
               T.Current_Style.Conceal := False;
            when 29 =>
               T.Current_Style.Strikethrough := False;
            when 53 =>
               T.Current_Style.Overline := True;
            when 55 =>
               T.Current_Style.Overline := False;
            when 59 =>
               T.Current_Style.Underline_Color := (others => <>);
            when 30 .. 37 =>
               T.Current_Style.Foreground := (Kind => Indexed, Index => P - 30, R => 0, G => 0, B => 0);
            when 40 .. 47 =>
               T.Current_Style.Background := (Kind => Indexed, Index => P - 40, R => 0, G => 0, B => 0);
            when 90 .. 97 =>
               T.Current_Style.Foreground := (Kind => Indexed, Index => P - 90 + 8, R => 0, G => 0, B => 0);
            when 100 .. 107 =>
               T.Current_Style.Background := (Kind => Indexed, Index => P - 100 + 8, R => 0, G => 0, B => 0);
            when 39 =>
               T.Current_Style.Foreground := (others => <>);
            when 49 =>
               T.Current_Style.Background := (others => <>);
            when 38 | 48 | 58 =>
               if I + 2 <= T.CSI_Count and then Param (T, I + 1, 0) = 5 then
                  declare
                     N : constant Natural := Param (T, I + 2, 0);
                     C : constant Color :=
                       (Kind => Indexed,
                        Index => Natural'Min (N, 255),
                        R => 0,
                        G => 0,
                        B => 0);
                  begin
                     if P = 38 then
                        T.Current_Style.Foreground := C;
                     elsif P = 48 then
                        T.Current_Style.Background := C;
                     else
                        T.Current_Style.Underline_Color := C;
                     end if;
                  end;
                  I := I + 2;
               elsif I + 4 <= T.CSI_Count and then Param (T, I + 1, 0) = 2 then
                  declare
                     C : constant Color :=
                       (Kind  => RGB,
                        Index => 0,
                        R     => Natural'Min (Param (T, I + 2, 0), 255),
                        G     => Natural'Min (Param (T, I + 3, 0), 255),
                        B     => Natural'Min (Param (T, I + 4, 0), 255));
                  begin
                     if P = 38 then
                        T.Current_Style.Foreground := C;
                     elsif P = 48 then
                        T.Current_Style.Background := C;
                     else
                        T.Current_Style.Underline_Color := C;
                     end if;
                  end;
                  I := I + 4;
               else
                  T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
               end if;
            when others =>
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         end case;
         I := I + 1;
      end loop;
   end Apply_SGR;

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
      Mark_Cursor_Move (T, Old_Row);
   end Soft_Reset;

   procedure Execute_CSI (T : in out Terminal; Final : Standard.Character) is
      N : Natural;
      R : Natural;
      C : Natural;

      function Min_Row return Positive is
      begin
         return (if T.Current_Modes.Origin_Mode then T.Top_Margin else 1);
      end Min_Row;

      function Max_Row return Positive is
      begin
         return (if T.Current_Modes.Origin_Mode then T.Bottom_Margin else T.Rows);
      end Max_Row;
   begin
      if T.CSI_Private = '<' or else T.CSI_Private = '=' then
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         return;
      end if;

      if T.CSI_Intermediate_Count > 0 then
         if T.CSI_Intermediate_Count = 1 then
            if T.CSI_Intermediates (1) = '!'
              and then T.CSI_Private = ASCII.NUL
              and then T.CSI_Count = 0
              and then Final = 'p'
            then
               Soft_Reset (T);
            elsif T.CSI_Intermediates (1) = ' '
              and then T.CSI_Private = ASCII.NUL
              and then T.CSI_Count <= 1
              and then Final = 'q'
            then
               case Param (T, 1, 1) is
                  when 0 | 1 =>
                     T.Current_Cursor_Shape := Cursor_Block;
                     T.Current_Cursor_Blinking := True;
                     T.Current_Modes.Cursor_Blinking := True;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 2 =>
                     T.Current_Cursor_Shape := Cursor_Block;
                     T.Current_Cursor_Blinking := False;
                     T.Current_Modes.Cursor_Blinking := False;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 3 =>
                     T.Current_Cursor_Shape := Cursor_Underline;
                     T.Current_Cursor_Blinking := True;
                     T.Current_Modes.Cursor_Blinking := True;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 4 =>
                     T.Current_Cursor_Shape := Cursor_Underline;
                     T.Current_Cursor_Blinking := False;
                     T.Current_Modes.Cursor_Blinking := False;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 5 =>
                     T.Current_Cursor_Shape := Cursor_Bar;
                     T.Current_Cursor_Blinking := True;
                     T.Current_Modes.Cursor_Blinking := True;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 6 =>
                     T.Current_Cursor_Shape := Cursor_Bar;
                     T.Current_Cursor_Blinking := False;
                     T.Current_Modes.Cursor_Blinking := False;
                     Mark_Dirty (T, T.Cursor_Row);
                  when others =>
                     T.Diag.Unsupported_Sequence :=
                       T.Diag.Unsupported_Sequence + 1;
               end case;
            elsif T.CSI_Intermediates (1) = '$'
              and then Final = 'p'
            then
               Queue_Mode_Report (T);
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         else
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         end if;
         return;
      end if;

      if T.CSI_Private /= ASCII.NUL
        and then Final not in 'c' | 'h' | 'i' | 'l' | 'n' | 't'
      then
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         return;
      end if;

      case Final is
         when '@' =>
            Shift_Row_Right
              (T,
               T.Cursor_Row,
               T.Cursor_Col,
               Positive'Min (T.Cols - T.Cursor_Col + 1, Positive'Max (1, Param (T, 1, 1))));
         when 'A' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Max
                   (Min_Row, T.Cursor_Row - Natural'Max (N, 1));
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'B' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Min
                   (Max_Row, T.Cursor_Row + Natural'Max (N, 1));
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'C' =>
            N := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, T.Cursor_Col + Natural'Max (N, 1));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'D' =>
            N := Param (T, 1, 1);
            T.Cursor_Col := Positive'Max (1, T.Cursor_Col - Natural'Max (N, 1));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'E' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Min
                   (Max_Row, T.Cursor_Row + Natural'Max (N, 1));
               T.Cursor_Col := 1;
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'F' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Max
                   (Min_Row, T.Cursor_Row - Natural'Max (N, 1));
               T.Cursor_Col := 1;
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'G' =>
            C := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, Positive'Max (1, C));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'H' | 'f' =>
            R := Param (T, 1, 1);
            C := Param (T, 2, 1);
            Move_Cursor (T, R, C);
         when 'I' =>
            Move_Forward_Tabs (T, Positive'Max (1, Param (T, 1, 1)));
         when 'J' =>
            N := Param (T, 1, 0);
            case N is
               when 0 =>
                  Clear_Row (T, T.Cursor_Row, T.Cursor_Col, T.Cols);
                  for Row in T.Cursor_Row + 1 .. T.Rows loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
               when 1 =>
                  for Row in 1 .. T.Cursor_Row - 1 loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
                  Clear_Row (T, T.Cursor_Row, 1, T.Cursor_Col);
               when 2 =>
                  for Row in 1 .. T.Rows loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
                  if T.Active = Alternate then
                     T.Alternate_Graphics_Generation :=
                       T.Alternate_Graphics_Generation + 1;
                     if T.Alternate_Graphics_Generation = 0 then
                        T.Alternate_Graphics_Generation := 1;
                     end if;
                  else
                     T.Primary_Graphics_Generation :=
                       T.Primary_Graphics_Generation + 1;
                     if T.Primary_Graphics_Generation = 0 then
                        T.Primary_Graphics_Generation := 1;
                     end if;
                  end if;
               when 3 =>
                  for Row in 1 .. T.Rows loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
                  T.Scrollback_Rows := 0;
                  if T.Active = Alternate then
                     T.Alternate_Graphics_Generation :=
                       T.Alternate_Graphics_Generation + 1;
                     if T.Alternate_Graphics_Generation = 0 then
                        T.Alternate_Graphics_Generation := 1;
                     end if;
                  else
                     T.Primary_Graphics_Generation :=
                       T.Primary_Graphics_Generation + 1;
                     if T.Primary_Graphics_Generation = 0 then
                        T.Primary_Graphics_Generation := 1;
                     end if;
                  end if;
               when others =>
                  T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end case;
         when 'K' =>
            N := Param (T, 1, 0);
            case N is
               when 0 => Clear_Row (T, T.Cursor_Row, T.Cursor_Col, T.Cols);
               when 1 => Clear_Row (T, T.Cursor_Row, 1, T.Cursor_Col);
               when 2 => Clear_Row (T, T.Cursor_Row, 1, T.Cols);
               when others => T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end case;
         when 'g' =>
            for I in 1 .. Natural'Max (T.CSI_Count, 1) loop
               N := Param (T, I, 0);
               case N is
                  when 0 =>
                     if T.Tab_Stops /= null then
                        T.Tab_Stops (T.Cursor_Col) := False;
                     end if;
                  when 3 =>
                     if T.Tab_Stops /= null then
                        for C in T.Tab_Stops'Range loop
                           T.Tab_Stops (C) := False;
                        end loop;
                     end if;
                  when others =>
                     T.Diag.Unsupported_Sequence :=
                       T.Diag.Unsupported_Sequence + 1;
               end case;
            end loop;
         when 'L' =>
            Insert_Blank_Lines
              (T,
               T.Cursor_Row,
               Positive'Max (1, Param (T, 1, 1)));
         when 'M' =>
            Delete_Lines
              (T,
               T.Cursor_Row,
               Positive'Max (1, Param (T, 1, 1)));
         when 'P' =>
            Shift_Row_Left
              (T,
               T.Cursor_Row,
               T.Cursor_Col,
               Positive'Min (T.Cols - T.Cursor_Col + 1, Positive'Max (1, Param (T, 1, 1))));
         when 'S' =>
            Scroll_Up_Region (T, T.Top_Margin, T.Bottom_Margin, Positive'Max (1, Param (T, 1, 1)));
         when 'T' =>
            Scroll_Down_Region (T, T.Top_Margin, T.Bottom_Margin, Positive'Max (1, Param (T, 1, 1)));
         when 'X' =>
            Erase_Characters
              (T,
               T.Cursor_Row,
               T.Cursor_Col,
               Positive'Min (T.Cols - T.Cursor_Col + 1, Positive'Max (1, Param (T, 1, 1))));
         when 'Z' =>
            Move_Backward_Tabs (T, Positive'Max (1, Param (T, 1, 1)));
         when '`' =>
            C := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, Positive'Max (1, C));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'a' =>
            N := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, T.Cursor_Col + Natural'Max (N, 1));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'b' =>
            Repeat_Last_Printable (T, Positive'Max (1, Param (T, 1, 1)));
         when 'c' =>
            Queue_Device_Attributes (T);
         when 'd' =>
            R := Param (T, 1, 1);
            if T.Current_Modes.Origin_Mode then
               Move_Cursor (T, R, T.Cursor_Col);
            else
               declare
                  Old_Row : constant Positive := T.Cursor_Row;
               begin
                  T.Cursor_Row := Positive'Min (T.Rows, Positive'Max (1, R));
                  Mark_Cursor_Move (T, Old_Row);
               end;
            end if;
         when 'e' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Min
                   (Max_Row, T.Cursor_Row + Natural'Max (N, 1));
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'i' =>
            if T.CSI_Private = ASCII.NUL then
               for I in 1 .. Natural'Max (T.CSI_Count, 1) loop
                  case Param (T, I, 0) is
                     when 0 | 4 | 5 =>
                        null;
                     when others =>
                        T.Diag.Unsupported_Sequence :=
                          T.Diag.Unsupported_Sequence + 1;
                  end case;
               end loop;
            elsif T.CSI_Private = '?' then
               for I in 1 .. Natural'Max (T.CSI_Count, 1) loop
                  case Param (T, I, 0) is
                     when 1 | 4 | 5 | 10 | 11 =>
                        null;
                     when others =>
                        T.Diag.Unsupported_Sequence :=
                          T.Diag.Unsupported_Sequence + 1;
                  end case;
               end loop;
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 'm' =>
            Apply_SGR (T);
         when 'n' =>
            Queue_Device_Status_Report (T, Param (T, 1, 0));
         when 's' =>
            if T.CSI_Private = ASCII.NUL and then T.CSI_Count = 0 then
               Save_Cursor_State (T);
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 't' =>
            Queue_Window_Operation_Report (T, Param (T, 1, 0));
         when 'u' =>
            if T.CSI_Private = ASCII.NUL and then T.CSI_Count = 0 then
               Restore_Cursor_State (T);
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 'h' | 'l' =>
            if T.CSI_Private = '?' then
               for I in 1 .. Natural'Max (T.CSI_Count, 1) loop
                  Set_Mode (T, Param (T, I, 0), Final = 'h');
               end loop;
            elsif T.CSI_Private = ASCII.NUL then
               for I in 1 .. Natural'Max (T.CSI_Count, 1) loop
                  case Param (T, I, 0) is
                     when 2 =>
                        T.Current_Modes.Keyboard_Locked := Final = 'h';
                     when 4 =>
                        T.Current_Modes.Insert_Mode := Final = 'h';
                     when 20 =>
                        T.Current_Modes.Linefeed_New_Line := Final = 'h';
                     when others =>
                        T.Diag.Unsupported_Sequence :=
                          T.Diag.Unsupported_Sequence + 1;
                  end case;
               end loop;
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 'r' =>
            R := Param (T, 1, 1);
            C := Param (T, 2, T.Rows);
            if R >= 1 and then C > R and then C <= T.Rows then
               T.Top_Margin := R;
               T.Bottom_Margin := C;
               Move_Cursor (T, 1, 1);
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when others =>
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end case;
      T.Pending_Wrap := False;
   end Execute_CSI;

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
      Status : out Feed_Status)
   is
      Ch : Standard.Character;
      Overflowed : Boolean := False;
      Recovered  : Boolean := False;
   begin
      if not T.Initialized then
         Status := Invalid_State;
         return;
      end if;

      T.Graphics_Queue_Overflowed := False;

      if T.Graphics_Input_Blocked then
         Status :=
           (if Append_Deferred_Input (T, Data) then Ok else Parser_Overflow);
         return;
      end if;

      for Data_Index in Data'Range loop
         declare
            B : constant Common.Bytes.Byte := Data (Data_Index);
         begin
         if T.Kitty_Chunk_Active then
            if T.State = Ground
              and then Natural (B) in 16#18# | 16#1A#
            then
               Advance_Graphics_Transaction (T);
               Enqueue_Graphics_Event
                 (T,
                  Kitty_Graphics,
                  T.Cursor_Row,
                  T.Cursor_Col,
                  "",
                  Cancelled => True);
               Clear_Kitty_Chunk (T);
            elsif T.State = Ground
              and then Natural (B) not in 16#1B# | 16#90# | 16#9F#
            then
               Reject_Kitty_Chunk_Interleave (T);
            elsif T.State = Escape
              and then Standard.Character'Val (Natural (B)) not in '_' | 'P'
            then
               Reject_Kitty_Chunk_Interleave (T);
            end if;
         end if;

         if Natural (B) = 16#9C#
           and then (In_String_Control (T.State) or else T.UTF8_Need = 0)
         then
            if T.State = OSC or else T.State = OSC_Escape then
               Finish_OSC (T);
               goto Continue;
            elsif T.State = OSC_Overflow
              or else T.State = OSC_Overflow_Escape
            then
               T.State := Ground;
               goto Continue;
            elsif T.State = Ignored_String
              or else T.State = Ignored_String_Escape
            then
               Finish_Ignored_String (T);
               goto Continue;
            elsif T.State = Ignored_String_Overflow
              or else T.State = Ignored_String_Overflow_Escape
            then
               T.Ignored_String_Is_DCS := False;
               T.Ignored_String_Is_APC := False;
               Clear_Graphics_Transfer (T);
               T.State := Ground;
               goto Continue;
            elsif not In_String_Control (T.State) then
               Recover_Incomplete_UTF8 (T);
               goto Continue;
            end if;
         elsif not In_String_Control (T.State) and then T.UTF8_Need = 0 then
            if Natural (B) = 16#9B# then
               Recover_Incomplete_UTF8 (T);
               Clear_CSI (T);
               T.State := CSI;
               goto Continue;
            elsif Natural (B) = 16#90# then
               Recover_Incomplete_UTF8 (T);
               Start_Ignored_String (T, Is_DCS => True);
               goto Continue;
            elsif Natural (B) = 16#98# then
               Recover_Incomplete_UTF8 (T);
               Start_Ignored_String (T, Is_DCS => False);
               goto Continue;
            elsif Natural (B) = 16#9E# then
               Recover_Incomplete_UTF8 (T);
               Start_Ignored_String (T, Is_DCS => False);
               goto Continue;
            elsif Natural (B) = 16#9F# then
               Recover_Incomplete_UTF8 (T);
               Start_Ignored_String (T, Is_DCS => False, Is_APC => True);
               goto Continue;
            elsif Natural (B) = 16#84# then
               Recover_Incomplete_UTF8 (T);
               Index_Control (T);
               goto Continue;
            elsif Natural (B) = 16#85# then
               Recover_Incomplete_UTF8 (T);
               Next_Line_Control (T);
               goto Continue;
            elsif Natural (B) = 16#88# then
               Recover_Incomplete_UTF8 (T);
               Horizontal_Tab_Set (T);
               goto Continue;
            elsif Natural (B) = 16#8C# then
               Recover_Incomplete_UTF8 (T);
               Reset_Terminal (T);
               goto Continue;
            elsif Natural (B) = 16#8D# then
               Recover_Incomplete_UTF8 (T);
               Reverse_Index_Control (T);
               goto Continue;
            elsif Natural (B) = 16#8E# then
               Recover_Incomplete_UTF8 (T);
               T.Single_Shift_Charset := G2;
               T.State := Single_Shift;
               goto Continue;
            elsif Natural (B) = 16#8F# then
               Recover_Incomplete_UTF8 (T);
               T.Single_Shift_Charset := G3;
               T.State := Single_Shift;
               goto Continue;
            elsif Natural (B) = 16#9D# then
               Recover_Incomplete_UTF8 (T);
               T.OSC_Count := 0;
               T.State := OSC;
               goto Continue;
            elsif Natural (B) = 16#7F# then
               Recover_Incomplete_UTF8 (T);
               goto Continue;
            end if;
         elsif Natural (B) = 16#7F# and then not In_String_Control (T.State) then
            Recover_Incomplete_UTF8 (T);
            goto Continue;
         end if;

         if Natural (B) < 32 then
            if T.State = OSC and then Natural (B) = 27 then
               T.State := OSC_Escape;
               goto Continue;
            elsif T.State = OSC_Overflow and then Natural (B) = 27 then
               T.State := OSC_Overflow_Escape;
               goto Continue;
            elsif T.State = Ignored_String and then Natural (B) = 27 then
               T.State := Ignored_String_Escape;
               goto Continue;
            elsif T.State = Ignored_String_Overflow and then Natural (B) = 27 then
               T.State := Ignored_String_Overflow_Escape;
               goto Continue;
            elsif T.State = OSC and then Natural (B) = 7 then
               Finish_OSC (T);
               goto Continue;
            elsif T.State = OSC_Overflow and then Natural (B) = 7 then
               T.State := Ground;
               goto Continue;
            elsif T.State = Ignored_String and then Natural (B) = 7 then
               Finish_Ignored_String (T);
               goto Continue;
            elsif T.State = Ignored_String_Overflow and then Natural (B) = 7 then
               T.Ignored_String_Is_DCS := False;
               T.Ignored_String_Is_APC := False;
               Clear_Graphics_Transfer (T);
               T.State := Ground;
               goto Continue;
            elsif (Natural (B) = 16#18# or else Natural (B) = 16#1A#)
              and then T.State /= Ground
            then
               if T.Kitty_Chunk_Active
                 and then T.Ignored_String_Is_APC
               then
                  --  CAN/SUB aborts the complete in-flight chunk transaction,
                  --  not merely the APC fragment currently being parsed.
                  --  Deliver an ordered marker so the app can release the
                  --  encoded segments it owns without manufacturing a Kitty
                  --  response or mutating any image placement.
                  Advance_Graphics_Transaction (T);
                  Enqueue_Graphics_Event
                    (T,
                     Kitty_Graphics,
                     T.Cursor_Row,
                     T.Cursor_Col,
                     "",
                     Cancelled => True);
                  Clear_Kitty_Chunk (T);
               end if;
               Recover_Incomplete_UTF8 (T);
               Clear_CSI (T);
               Clear_Graphics_Transfer (T);
               T.Ignored_String_Is_DCS := False;
               T.Ignored_String_Is_APC := False;
               T.State := Ground;
               goto Continue;
            elsif T.State = Single_Shift then
               T.State := Ground;
               Recover_Incomplete_UTF8 (T);
               Execute_C0 (T, B);
               goto Continue;
            elsif not In_String_Control (T.State) then
               Recover_Incomplete_UTF8 (T);
               Execute_C0 (T, B);
               goto Continue;
            end if;
         end if;

         Ch := Standard.Character'Val (Natural (B));
         case T.State is
            when Ground =>
               Decode_Printable (T, B);
            when Escape =>
               case Ch is
                  when 'c' =>
                     Reset_Terminal (T);
                     T.State := Ground;
                  when '7' =>
                     Save_Cursor_State (T);
                     T.State := Ground;
                  when '8' =>
                     Restore_Cursor_State (T);
                     T.State := Ground;
                  when 'D' =>
                     Index_Control (T);
                     T.State := Ground;
                  when 'E' =>
                     Next_Line_Control (T);
                     T.State := Ground;
                  when 'H' =>
                     Horizontal_Tab_Set (T);
                     T.State := Ground;
                  when 'M' =>
                     Reverse_Index_Control (T);
                     T.State := Ground;
                  when 'N' =>
                     T.Single_Shift_Charset := G2;
                     T.State := Single_Shift;
                  when 'O' =>
                     T.Single_Shift_Charset := G3;
                     T.State := Single_Shift;
                  when 'Z' =>
                     Queue_Device_Attributes (T);
                     T.State := Ground;
                  when '[' =>
                     Clear_CSI (T);
                     T.State := CSI;
                  when ']' =>
                     T.OSC_Count := 0;
                     T.State := OSC;
                  when 'P' =>
                     Start_Ignored_String (T, Is_DCS => True);
                  when 'X' =>
                     Start_Ignored_String (T, Is_DCS => False);
                  when '^' =>
                     Start_Ignored_String (T, Is_DCS => False);
                  when '_' =>
                     Start_Ignored_String
                       (T, Is_DCS => False, Is_APC => True);
                  when '(' =>
                     T.Charset_Target := G0;
                     T.State := Charset;
                  when ')' | '-' =>
                     T.Charset_Target := G1;
                     T.State := Charset;
                  when '*' | '.' =>
                     T.Charset_Target := G2;
                     T.State := Charset;
                  when '+' | '/' =>
                     T.Charset_Target := G3;
                     T.State := Charset;
                  when '%' =>
                     T.State := Coding_System;
                  when '#' =>
                     T.State := Screen_Alignment;
                  when '=' =>
                     T.Current_Modes.Application_Keypad := True;
                     T.State := Ground;
                  when '>' =>
                     T.Current_Modes.Application_Keypad := False;
                     T.State := Ground;
                  when others =>
                     T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                     Recovered := True;
                     T.State := Ground;
               end case;
            when CSI =>
               if Ch in '<' .. '?'
                 and then T.CSI_Count = 0
                 and then T.CSI_Private = ASCII.NUL
               then
                  T.CSI_Private := Ch;
               elsif Ch in '0' .. '9' then
                  if T.CSI_Count = 0 then
                     T.CSI_Count := 1;
                  end if;
                  T.CSI_Set (T.CSI_Count) := True;
                  T.CSI_Params (T.CSI_Count) :=
                    Natural'Min (T.CSI_Params (T.CSI_Count) * 10 + Standard.Character'Pos (Ch) - Standard.Character'Pos ('0'), Natural'Last / 2);
               elsif Ch = ';' or else Ch = ':' then
                  if T.CSI_Count < Parser.Max_CSI_Params then
                     T.CSI_Count := T.CSI_Count + 1;
                     T.CSI_Separators (T.CSI_Count) := Ch;
                  else
                     T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                     Overflowed := True;
                  end if;
               elsif Ch in ' ' .. '/' then
                  if T.CSI_Intermediate_Count < Parser.Max_CSI_Intermediate then
                     T.CSI_Intermediate_Count := T.CSI_Intermediate_Count + 1;
                     T.CSI_Intermediates (T.CSI_Intermediate_Count) := Ch;
                  else
                     T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                     Overflowed := True;
                  end if;
               elsif Ch in '@' .. '~' then
                  Execute_CSI (T, Ch);
                  Clear_CSI (T);
                  T.State := Ground;
               else
                  T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                  Recovered := True;
                  Clear_CSI (T);
                  T.State := Ground;
               end if;
            when OSC =>
               Append_OSC_Byte (T, Ch, Overflowed);
            when OSC_Escape =>
               if Ch = '\' then
                  Finish_OSC (T);
               else
                  Append_OSC_Byte (T, ASCII.ESC, Overflowed);
                  if T.State = OSC_Overflow then
                     goto Continue;
                  end if;
                  Append_OSC_Byte (T, Ch, Overflowed);
                  if T.State /= OSC_Overflow then
                     T.State := OSC;
                  end if;
               end if;
            when OSC_Overflow =>
               null;
            when OSC_Overflow_Escape =>
               if Ch = '\' then
                  T.State := Ground;
               else
                  T.State := OSC_Overflow;
               end if;
            when Ignored_String =>
               Append_Ignored_String_Byte (T, Ch, Overflowed);
            when Ignored_String_Escape =>
               if Ch = '\' then
                  Finish_Ignored_String (T);
               else
                  Append_Ignored_String_Byte (T, ASCII.ESC, Overflowed);
                  if T.State /= Ignored_String_Overflow then
                     Append_Ignored_String_Byte (T, Ch, Overflowed);
                     if T.State /= Ignored_String_Overflow then
                        T.State := Ignored_String;
                     end if;
                  end if;
               end if;
            when Ignored_String_Overflow =>
               null;
            when Ignored_String_Overflow_Escape =>
               if Ch = '\' then
                  T.Ignored_String_Is_DCS := False;
                  T.Ignored_String_Is_APC := False;
                  Clear_Graphics_Transfer (T);
                  T.State := Ground;
               else
                  T.State := Ignored_String_Overflow;
               end if;
            when Charset =>
               if Ch = '0' or else Ch = 'B' or else Ch = '@' then
                  declare
                     New_Charset : constant Charset_Kind :=
                       (if Ch = '0' then DEC_Special_Graphics else ASCII_Charset);
                  begin
                     case T.Charset_Target is
                        when G0 =>
                           T.G0_Charset := New_Charset;
                        when G1 =>
                           T.G1_Charset := New_Charset;
                        when G2 =>
                           T.G2_Charset := New_Charset;
                        when G3 =>
                           T.G3_Charset := New_Charset;
                     end case;
                  end;
               else
                  T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                  Recovered := True;
               end if;
               T.State := Ground;
            when Coding_System =>
               if Ch /= 'G' and then Ch /= '@' then
                  T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                  Recovered := True;
               end if;
               T.State := Ground;
            when Single_Shift =>
               if Natural (B) < 16#80# then
                  declare
                     Saved_Active : constant Charset_Slot := T.Active_Charset;
                  begin
                     T.Active_Charset := T.Single_Shift_Charset;
                     Decode_Printable (T, B);
                     T.Active_Charset := Saved_Active;
                  end;
               else
                  Decode_Printable (T, B);
               end if;
               T.State := Ground;
            when Screen_Alignment =>
               if Ch = '8' then
                  Screen_Alignment_Test (T);
               else
                  T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                  Recovered := True;
               end if;
               T.State := Ground;
         end case;

         <<Continue>>
         null;
         if T.Graphics_Input_Blocked then
            if Data_Index < Data'Last
              and then not Append_Deferred_Input
                (T, Data (Data_Index + 1 .. Data'Last))
            then
               Overflowed := True;
            end if;
            exit;
         end if;
         end;
      end loop;

      if Overflowed or else T.Graphics_Queue_Overflowed then
         Status := Parser_Overflow;
      elsif Recovered then
         Status := Parser_Recovered;
      else
         Status := Ok;
      end if;
   end Feed;

   procedure Resize
     (T      : in out Terminal;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Resize_Status)
   is
      Old_Primary  : Cell_Array_Access := T.Primary_Cells;
      Old_Alt      : Cell_Array_Access := T.Alt_Cells;
      Old_Scrollback : Cell_Array_Access := T.Scrollback;
      Old_Dirty    : Dirty_Row_Array_Access := T.Dirty;
      Old_Tabs     : Tab_Stop_Array_Access := T.Tab_Stops;
      New_Primary  : Cell_Array_Access := null;
      New_Alt      : Cell_Array_Access := null;
      New_Scrollback : Cell_Array_Access := null;
      New_Dirty    : Dirty_Row_Array_Access := null;
      New_Tabs     : Tab_Stop_Array_Access := null;
      Old_Rows    : constant Positive := T.Rows;
      Old_Cols    : constant Positive := T.Cols;
      New_Count   : Positive;
   begin
      if not T.Initialized then
         Status := Allocation_Failed;
         return;
      end if;

      --  A resize request is also issued to synchronize the PTY and terminal
      --  grid.  Treat an unchanged grid as a true no-op: rebuilding the cell
      --  and scrollback storage here is both expensive and destructive.
      if Rows = T.Rows and then Cols = T.Cols then
         Status := Ok;
         return;
      end if;

      if Rows > Positive'Last / Cols
        or else
          (T.Scrollback_Limit > 0
           and then T.Scrollback_Limit > Natural'Last / Cols)
      then
         Status := Allocation_Failed;
         return;
      end if;
      New_Count := Rows * Cols;

      --  Allocate the complete replacement before changing terminal state.
      --  A failed resize must leave every old buffer and all history usable.
      New_Primary := new Cell_Array (1 .. New_Count);
      New_Alt := new Cell_Array (1 .. New_Count);
      if T.Scrollback_Limit > 0 then
         New_Scrollback := new Cell_Array (1 .. T.Scrollback_Limit * Cols);
      end if;
      New_Dirty := new Dirty_Row_Array (1 .. Rows);
      New_Tabs := new Tab_Stop_Array (1 .. Cols);

      --  Populate the replacement while it is still detached from T.  This
      --  keeps even a bounds or assignment failure transactional, rather than
      --  exposing a partially initialized live screen.
      for I in New_Primary'Range loop
         New_Primary (I) := Blank_Cell (T.Current_Style);
         New_Alt (I) := Blank_Cell (T.Current_Style);
      end loop;
      New_Dirty.all := (others => True);
      for C in New_Tabs'Range loop
         New_Tabs (C) := C > 1 and then (C - 1) mod 8 = 0;
      end loop;
      for R in 1 .. Positive'Min (Old_Rows, Rows) loop
         for C in 1 .. Positive'Min (Old_Cols, Cols) loop
            New_Primary ((R - 1) * Cols + C) :=
              Old_Primary ((R - 1) * Old_Cols + C);
            New_Alt ((R - 1) * Cols + C) :=
              Old_Alt ((R - 1) * Old_Cols + C);
         end loop;
      end loop;
      if Old_Tabs /= null then
         for C in 1 .. Positive'Min (Old_Cols, Cols) loop
            New_Tabs (C) := Old_Tabs (C);
         end loop;
      end if;

      T.Primary_Cells := New_Primary;
      T.Alt_Cells := New_Alt;
      T.Scrollback := New_Scrollback;
      T.Dirty := New_Dirty;
      T.Tab_Stops := New_Tabs;
      New_Primary := null;
      New_Alt := null;
      New_Scrollback := null;
      New_Dirty := null;
      New_Tabs := null;

      T.Rows := Rows;
      T.Cols := Cols;
      T.Scrollback_Rows := 0;

      if Old_Primary /= null then
         Free_Cells (Old_Primary);
      end if;
      if Old_Alt /= null then
         Free_Cells (Old_Alt);
      end if;
      if Old_Scrollback /= null then
         Free_Cells (Old_Scrollback);
      end if;
      if Old_Dirty /= null then
         Free_Dirty (Old_Dirty);
      end if;
      if Old_Tabs /= null then
         Free_Tab_Stops (Old_Tabs);
      end if;

      T.Cursor_Row := Positive'Min (Rows, T.Cursor_Row);
      T.Cursor_Col := Positive'Min (Cols, T.Cursor_Col);
      T.Top_Margin := 1;
      T.Bottom_Margin := Rows;
      Mark_All_Dirty (T);
      Status := Ok;
   exception
      when Storage_Error | Constraint_Error =>
         if New_Primary /= null then
            Free_Cells (New_Primary);
         end if;
         if New_Alt /= null then
            Free_Cells (New_Alt);
         end if;
         if New_Scrollback /= null then
            Free_Cells (New_Scrollback);
         end if;
         if New_Dirty /= null then
            Free_Dirty (New_Dirty);
         end if;
         if New_Tabs /= null then
            Free_Tab_Stops (New_Tabs);
         end if;
         Status := Allocation_Failed;
   end Resize;

   procedure Snapshot
     (T : Terminal;
      S : in out Render_Snapshot)
   is
      Count : constant Natural := T.Rows * T.Cols;
      Src   : constant Cell_Array_Access := Active_Cells (T);
      Scroll_Head : constant Natural :=
        (if T.Active = Alternate
         then T.Alternate_Graphics_Scroll_Head
         else T.Primary_Graphics_Scroll_Head);
      Scroll_Count : constant Natural :=
        (if T.Active = Alternate
         then T.Alternate_Graphics_Scroll_Count
         else T.Primary_Graphics_Scroll_Count);
   begin
      S.Rows := T.Rows;
      S.Cols := T.Cols;
      S.Graphics_Stream := T.Graphics_Stream;
      S.Graphics_Transaction := T.Graphics_Transaction;
      S.Alternate_Screen := T.Active = Alternate;
      S.Screen_Generation :=
        (if T.Active = Alternate
         then T.Alternate_Graphics_Generation
         else T.Primary_Graphics_Generation);
      S.Scrollback_Offset := 0;
      S.Scrollback_Rows :=
        (if T.Active = Primary then T.Scrollback_Rows else 0);
      S.Graphics_Scroll_Current :=
        (if T.Active = Alternate
         then T.Alternate_Graphics_Scroll_Sequence
         else T.Primary_Graphics_Scroll_Sequence);
      S.Graphics_Scroll_Count := Scroll_Count;
      S.Graphics_Scroll_Oldest := 0;
      if Scroll_Count > 0 then
         if S.Graphics_Scroll_Events = null
           or else S.Graphics_Scroll_Events'Length < Scroll_Count
         then
            declare
               Replacement : constant Graphics_Scroll_Event_Array_Access :=
                 new Graphics_Scroll_Event_Array (1 .. Scroll_Count);
            begin
               if S.Graphics_Scroll_Events /= null then
                  Free_Graphics_Scroll_Events (S.Graphics_Scroll_Events);
               end if;
               S.Graphics_Scroll_Events := Replacement;
            end;
         end if;
         for I in 1 .. Scroll_Count loop
            declare
               Slot : constant Positive :=
                 ((Scroll_Head + I - 1) mod Max_Graphics_Scroll_Events) + 1;
            begin
               S.Graphics_Scroll_Events (I) :=
                 (if T.Active = Alternate
                  then T.Alternate_Graphics_Scroll_Events (Slot)
                  else T.Primary_Graphics_Scroll_Events (Slot));
            end;
         end loop;
         S.Graphics_Scroll_Oldest := S.Graphics_Scroll_Events (1).Sequence;
      end if;
      if S.Cells = null or else S.Cells'Length /= Count then
         declare
            Replacement : constant Cell_Array_Access :=
              new Cell_Array (1 .. Count);
         begin
            if S.Cells /= null then
               Free_Cells (S.Cells);
            end if;
            S.Cells := Replacement;
         end;
      end if;
      if S.Dirty = null or else S.Dirty'Length /= T.Rows then
         declare
            Replacement : constant Dirty_Row_Array_Access :=
              new Dirty_Row_Array (1 .. T.Rows);
         begin
            if S.Dirty /= null then
               Free_Dirty (S.Dirty);
            end if;
            S.Dirty := Replacement;
         end;
      end if;
      S.Image_Cell_Count := 0;
      for I in 1 .. Count loop
         S.Cells (I) := Src (I);
         if Src (I).Image.Is_Placeholder then
            S.Image_Cell_Count := S.Image_Cell_Count + 1;
         end if;
      end loop;
      for R in 1 .. T.Rows loop
         S.Dirty (R) := T.Dirty (R);
      end loop;
      S.Cursor :=
        (Row     => T.Cursor_Row,
         Col     => T.Cursor_Col,
         Visible => T.Current_Modes.Cursor_Visible,
         Shape   => T.Current_Cursor_Shape,
         Blinking => T.Current_Cursor_Blinking);
      S.Graphics := T.Last_Graphics;
   end Snapshot;

   function Snapshot (T : Terminal) return Render_Snapshot is
      S : Render_Snapshot;
   begin
      Snapshot (T, S);
      return S;
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
   begin
      T.Cell_Pixel_Width := Width;
      T.Cell_Pixel_Height := Height;
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
      Event.Stream_ID := T.Graphics_Stream;
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
        or else Event.Stream_ID /= T.Graphics_Stream
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
   is
      Node : constant Graphics_Event_Node_Access := T.Graphics_Head;
      Was_Blocking : Boolean := False;
      Was_Blocked : Boolean := False;

      function Message return String is
      begin
         case Result.Code is
            when Kitty_No_Response => return "";
            when Kitty_OK          => return "OK";
            when Kitty_EINVAL      => return "EINVAL:Invalid control data";
            when Kitty_ENOENT      => return "ENOENT:Image or placement not found";
            when Kitty_ENOMEM      => return "ENOMEM:Image resource limit exceeded";
            when Kitty_ENOSPC      => return "ENOSPC:Insufficient animation storage";
            when Kitty_EBADF       => return "EBADF:Failed to read image file";
            when Kitty_ENOTSUP     => return "ENOTSUP:Unsupported graphics operation";
            when Kitty_ENOPARENT   => return "ENOPARENT:Parent placement not found";
            when Kitty_ECYCLE      => return "ECYCLE:Relative placement cycle";
            when Kitty_ETOODEEP    => return "ETOODEEP:Relative placement chain too deep";
         end case;
      end Message;
   begin
      if Node = null
        or else not Event.Pending
        or else Event.Protocol /= Node.Protocol
        or else Event.Stream_ID /= T.Graphics_Stream
        or else Event.Sequence /= Node.Sequence
      then
         return;
      end if;

      Was_Blocking := Node.Blocks_Input;
      Was_Blocked := T.Graphics_Input_Blocked;

      if Node.Protocol = Kitty_Graphics
        and then Result.Code /= Kitty_No_Response
        and then Result.Respond
        and then Result.Quiet /= 2
        and then not (Result.Code = Kitty_OK and then Result.Quiet = 1)
      then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_String (T, "_Gi=");
         Append_Response_Graphics_ID (T, Result.Image_ID);
         if Result.Has_Image_Number then
            Append_Response_String (T, ",I=");
            Append_Response_Graphics_ID (T, Result.Image_Number);
         end if;
         if Result.Has_Placement_ID then
            Append_Response_String (T, ",p=");
            Append_Response_Graphics_ID (T, Result.Placement_ID);
         end if;
         Append_Response_Char (T, ';');
         Append_Response_String (T, Message);
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '\');
      end if;

      if Was_Blocking
        and then Result.Code = Kitty_OK
        and then Result.Move_Cursor
      then
         declare
            Target_Row : Positive;
            Target_Col : Positive;
         begin
            if Result.Placement_Rows > T.Rows - Event.Row then
               Target_Row := T.Rows;
            else
               Target_Row := Event.Row + Result.Placement_Rows;
            end if;
            if Result.Cursor_To_Line_Start then
               Target_Col := 1;
            elsif Result.Placement_Columns > T.Cols - Event.Col then
               Target_Col := T.Cols;
            else
               Target_Col := Event.Col + Result.Placement_Columns;
            end if;
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               T.Cursor_Row := Target_Row;
               T.Cursor_Col := Target_Col;
               T.Pending_Wrap := False;
               Mark_Cursor_Move (T, Old_Row);
            end;
         end;
      end if;

      Drop_Graphics_Head (T);
      Refresh_Graphics_Input_Block (T);
      if Was_Blocked and then not T.Graphics_Input_Blocked then
         Resume_Deferred_Input (T);
      end if;
   end Complete_Graphics_Event;

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
