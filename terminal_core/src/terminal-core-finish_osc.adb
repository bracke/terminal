with Terminal.Core.Graphics_Runtime;

separate (Terminal.Core)
procedure Finish_OSC (T : in out Terminal) is
   Command : Natural := 0;
   Payload_First : Natural := 0;
   Title_Length : Natural;

   function Payload_Starts_With (Text : String) return Boolean is
   begin
      if Payload_First = 0
        or else T.Parser.OSC_Count - Payload_First + 1 < Text'Length
      then
         return False;
      end if;

      for I in Text'Range loop
         if T.Parser.OSC_Data (Payload_First + I - Text'First) /= Text (I) then
            return False;
         end if;
      end loop;
      return True;
   end Payload_Starts_With;

   procedure Decode_OSC7
     (First : Natural;
      Last  : Natural)
   is
      Prefix : constant String := "file://";
      Path_First : Natural := 0;
      Out_Length : Natural := 0;
      Invalid : Boolean := False;

      function Hex_Value (Ch : Standard.Character) return Natural is
      begin
         if Ch in '0' .. '9' then
            return Standard.Character'Pos (Ch) - Standard.Character'Pos ('0');
         elsif Ch in 'a' .. 'f' then
            return Standard.Character'Pos (Ch) - Standard.Character'Pos ('a') + 10;
         elsif Ch in 'A' .. 'F' then
            return Standard.Character'Pos (Ch) - Standard.Character'Pos ('A') + 10;
         else
            return 16;
         end if;
      end Hex_Value;

      procedure Append (Ch : Standard.Character) is
      begin
         if Ch in ASCII.NUL .. ASCII.US or else Ch = ASCII.DEL then
            Invalid := True;
         elsif Out_Length = Max_Working_Directory_Length then
            Increment_Saturating (T.Diag.Parser_Overflow);
            Invalid := True;
         else
            Out_Length := Out_Length + 1;
            T.Shell_State.Working_Directory.Text (Out_Length) := Ch;
         end if;
      end Append;

      I : Natural;
   begin
      if Last < First or else Last - First + 1 < Prefix'Length then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      end if;
      for J in Prefix'Range loop
         if T.Parser.OSC_Data (First + J - Prefix'First) /= Prefix (J) then
            Increment_Saturating (T.Diag.Unsupported_Sequence);
            return;
         end if;
      end loop;

      --  Skip the authority.  OSC 7 commonly uses file://host/path and
      --  file:///path; the terminal only needs the decoded local path.
      I := First + Prefix'Length;
      while I <= Last and then T.Parser.OSC_Data (I) /= '/' loop
         I := I + 1;
      end loop;
      if I > Last then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      end if;
      Path_First := I;
      T.Shell_State.Working_Directory := (others => <>);
      I := Path_First;
      while I <= Last and then not Invalid loop
         if T.Parser.OSC_Data (I) = '%' and then I + 2 <= Last then
            declare
               High : constant Natural := Hex_Value (T.Parser.OSC_Data (I + 1));
               Low  : constant Natural := Hex_Value (T.Parser.OSC_Data (I + 2));
            begin
               if High > 15 or else Low > 15 then
                  Invalid := True;
               else
                  Append (Standard.Character'Val (High * 16 + Low));
                  I := I + 3;
               end if;
            end;
         else
            Append (T.Parser.OSC_Data (I));
            I := I + 1;
         end if;
      end loop;
      if Invalid or else Out_Length = 0 then
         T.Shell_State.Working_Directory := (others => <>);
         Increment_Saturating (T.Diag.Unsupported_Sequence);
      else
         T.Shell_State.Working_Directory.Length := Out_Length;
      end if;
   end Decode_OSC7;

   procedure Decode_OSC133
     (First : Natural;
      Last  : Natural)
   is
      Marker : Standard.Character;
      Value : Natural := 0;
      Has_Value : Boolean := False;
      Duration_Value : Natural := 0;
      Has_Duration : Boolean := False;
      Valid : Boolean := True;
      function Current_History_Row return Natural is
      begin
         if T.History_Rows <= Natural'Last - T.Cursor_Row then
            return T.History_Rows + T.Cursor_Row;
         end if;
         return Natural'Last;
      end Current_History_Row;
      procedure Add_Mark (Kind : Shell_Mark_Kind) is
         Row : Natural := T.History_Rows;
         Slot : Shell_Mark_Index;
      begin
         if Row <= Natural'Last - T.Cursor_Row then
            Row := Row + T.Cursor_Row;
         else
            Row := Natural'Last;
         end if;
         Slot := Shell_Mark_Index (T.Shell_Mark_Head + 1);
         T.Shell_Marks (Slot) := (Kind => Kind, History_Row => Row);
         T.Shell_Mark_Head := (T.Shell_Mark_Head + 1) mod Max_Shell_Marks;
         if T.Shell_Mark_Total < Max_Shell_Marks then
            T.Shell_Mark_Total := T.Shell_Mark_Total + 1;
         end if;
      end Add_Mark;

      procedure Start_Block is
         Slot : constant Shell_Command_Block_Index :=
           Shell_Command_Block_Index (T.Shell_Command_Block_Head + 1);
      begin
         T.Shell_Command_Blocks (Slot) :=
           (Sequence   => T.Next_Shell_Command_Sequence,
            Prompt_Row => Current_History_Row,
            Prompt_Col => T.Cursor_Col,
            Has_Prompt => True,
            others      => <>);
         Increment_Saturating (T.Next_Shell_Command_Sequence);
         T.Shell_Command_Block_Head :=
           (T.Shell_Command_Block_Head + 1) mod Max_Shell_Command_Blocks;
         if T.Shell_Command_Block_Total < Max_Shell_Command_Blocks then
            T.Shell_Command_Block_Total := T.Shell_Command_Block_Total + 1;
         end if;
         T.Current_Shell_Command_Block := Natural (Slot);
      end Start_Block;

      procedure Ensure_Block is
      begin
         if T.Current_Shell_Command_Block = 0 then
            Start_Block;
         end if;
      end Ensure_Block;
   begin
      if First > Last then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      end if;
      Marker := T.Parser.OSC_Data (First);
      if First < Last then
         if T.Parser.OSC_Data (First + 1) /= ';' then
            Valid := False;
         elsif First + 2 <= Last then
            declare
               Field : Positive range 1 .. 2 := 1;
               Has_Digit : Boolean := False;
            begin
            for I in First + 2 .. Last loop
               if T.Parser.OSC_Data (I) = ';' then
                  if not Has_Digit or else Field = 2 then
                     Valid := False;
                     exit;
                  end if;
                  Has_Value := True;
                  Field := 2;
                  Has_Digit := False;
               elsif T.Parser.OSC_Data (I) not in '0' .. '9' then
                  Valid := False;
                  exit;
               elsif Field = 1 then
                  Has_Digit := True;
                  Value := Append_Decimal_Digit
                    (Value,
                     Standard.Character'Pos (T.Parser.OSC_Data (I))
                       - Standard.Character'Pos ('0'),
                     Natural (Integer'Last));
               else
                  Has_Digit := True;
                  Duration_Value := Append_Decimal_Digit
                    (Duration_Value,
                     Standard.Character'Pos (T.Parser.OSC_Data (I))
                       - Standard.Character'Pos ('0'),
                     Natural'Last);
               end if;
            end loop;
            if Valid and then not Has_Digit then
               Valid := False;
            elsif Valid and then Field = 1 then
               Has_Value := True;
            elsif Valid then
               Has_Duration := True;
            end if;
            end;
         end if;
      end if;
      if not Valid then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      end if;

      case Marker is
         when 'A' =>
            T.Shell_State.Zone := Prompt_Zone;
            Increment_Saturating (T.Shell_State.Prompt_Count);
            Start_Block;
            Add_Mark (Prompt_Mark);
         when 'B' =>
            T.Shell_State.Zone := Input_Zone;
            Increment_Saturating (T.Shell_State.Command_Count);
            Ensure_Block;
            T.Shell_Command_Blocks
              (Shell_Command_Block_Index (T.Current_Shell_Command_Block))
                .Input_Row := Current_History_Row;
            T.Shell_Command_Blocks
              (Shell_Command_Block_Index (T.Current_Shell_Command_Block))
                .Input_Col := T.Cursor_Col;
            T.Shell_Command_Blocks
              (Shell_Command_Block_Index (T.Current_Shell_Command_Block))
                .Has_Input := True;
            Add_Mark (Command_Mark);
         when 'C' =>
            T.Shell_State.Zone := Output_Zone;
            Increment_Saturating (T.Shell_State.Output_Count);
            Ensure_Block;
            T.Shell_Command_Blocks
              (Shell_Command_Block_Index (T.Current_Shell_Command_Block))
                .Output_Row := Current_History_Row;
            T.Shell_Command_Blocks
              (Shell_Command_Block_Index (T.Current_Shell_Command_Block))
                .Output_Col := T.Cursor_Col;
            T.Shell_Command_Blocks
              (Shell_Command_Block_Index (T.Current_Shell_Command_Block))
                .Has_Output := True;
         when 'D' =>
            T.Shell_State.Zone := No_Semantic_Zone;
            Increment_Saturating (T.Shell_State.Completion_Count);
            T.Shell_State.Has_Exit_Status := Has_Value;
            if Has_Value then
               T.Shell_State.Last_Exit_Status := Integer (Value);
            end if;
            Ensure_Block;
            declare
               Slot : constant Shell_Command_Block_Index :=
                 Shell_Command_Block_Index (T.Current_Shell_Command_Block);
            begin
               T.Shell_Command_Blocks (Slot).Completion_Row :=
                 Current_History_Row;
               T.Shell_Command_Blocks (Slot).Completion_Col := T.Cursor_Col;
               T.Shell_Command_Blocks (Slot).Complete := True;
               T.Shell_Command_Blocks (Slot).Has_Exit_Status := Has_Value;
               if Has_Value then
                  T.Shell_Command_Blocks (Slot).Exit_Status := Integer (Value);
               end if;
               T.Shell_Command_Blocks (Slot).Has_Duration := Has_Duration;
               if Has_Duration then
                  T.Shell_Command_Blocks (Slot).Duration_Milliseconds :=
                    Duration_Value;
               end if;
            end;
            T.Current_Shell_Command_Block := 0;
            if not T.Notification_Data.Pending then
               T.Notification_Data :=
                 (Pending => True,
                  Kind => Command_Completion,
                  Title => (others => <>),
                  Message => (others => <>),
                  Bell_Count => 0);
               T.Notification_Data.Title.Length := 16;
               T.Notification_Data.Title.Text (1 .. 16) :=
                 "Command finished";
               if Has_Value then
                  declare
                     Message : constant String :=
                       "Exit status" & Integer'Image (Integer (Value));
                  begin
                     T.Notification_Data.Message.Length := Message'Length;
                     T.Notification_Data.Message.Text
                       (1 .. Message'Length) := Message;
                  end;
               end if;
            end if;
         when others =>
            Increment_Saturating (T.Diag.Unsupported_Sequence);
      end case;
   end Decode_OSC133;

   procedure Set_Notification_Text
     (Target : out Notification_Text;
      First  : Natural;
      Last   : Natural)
   is
      Count : Natural := 0;
   begin
      Target := (others => <>);
      if First > Last then
         return;
      end if;
      for I in First .. Last loop
         exit when Count = Max_Notification_Text_Length;
         if T.Parser.OSC_Data (I) in ASCII.NUL .. ASCII.US
           or else T.Parser.OSC_Data (I) = ASCII.DEL
         then
            exit;
         end if;
         Count := Count + 1;
         Target.Text (Count) := T.Parser.OSC_Data (I);
      end loop;
      Target.Length := Count;
      if Last - First + 1 > Max_Notification_Text_Length then
         Increment_Saturating (T.Diag.Parser_Overflow);
      end if;
   end Set_Notification_Text;

   procedure Decode_Notification_Text
     (Target : out Notification_Text;
      First  : Natural;
      Last   : Natural;
      Valid  : out Boolean)
   is
      Decoder : Common.Base64.Decoder_State;
      Bytes : Common.Base64.Decoded_Quantum;
      Count : Natural := 0;
      Decode_Status : Common.Base64.Decoder_Status;
      procedure Append_Output is
      begin
         if Decode_Status = Common.Base64.Invalid_Data then
            Valid := False;
            return;
         end if;
         for I in 1 .. Count loop
            if Target.Length = Max_Notification_Text_Length
              or else Natural (Bytes (I)) < 32
              or else Natural (Bytes (I)) in 127 .. 159
            then
               Valid := False;
               return;
            end if;
            Target.Length := Target.Length + 1;
            Target.Text (Target.Length) :=
              Standard.Character'Val (Natural (Bytes (I)));
         end loop;
      end Append_Output;
   begin
      Target := (others => <>);
      Valid := True;
      Common.Base64.Reset
        (Decoder, Allow_Unpadded => True, Allow_Whitespace => False);
      if First <= Last then
         for I in First .. Last loop
            Common.Base64.Push
              (Decoder, T.Parser.OSC_Data (I), Bytes, Count, Decode_Status);
            Append_Output;
            exit when not Valid;
         end loop;
      end if;
      if Valid then
         Common.Base64.Finish (Decoder, Bytes, Count, Decode_Status);
         Append_Output;
      end if;
      if not Valid then
         Target := (others => <>);
      end if;
   end Decode_Notification_Text;

   procedure Decode_OSC9 (First : Natural; Last : Natural) is
   begin
      T.Notification_Data.Kind := Desktop_Notification;
      Set_Notification_Text (T.Notification_Data.Title, First, Last);
      T.Notification_Data.Message := (others => <>);
      T.Notification_Data.Pending :=
        T.Notification_Data.Title.Length > 0;
   end Decode_OSC9;

   procedure Decode_OSC99 (First : Natural; Last : Natural) is
      Separator : Natural := 0;
      Payload_Kind : Standard.Character := 't';
      Done : Boolean := True;
      Encoded : Boolean := False;
      Valid_Payload : Boolean := True;
      Valid_Metadata : Boolean := True;
      I : Natural;
   begin
      if First > Last then
         return;
      end if;
      for J in First .. Last loop
         if T.Parser.OSC_Data (J) = ';' then
            Separator := J;
            exit;
         end if;
      end loop;
      if Separator = 0 then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      end if;
      I := First;
      while I < Separator loop
         declare
            Field_Last : Natural := I;
            function Value_Is (Expected : String) return Boolean is
            begin
               if Field_Last - (I + 2) /= Expected'Length then
                  return False;
               end if;
               for J in Expected'Range loop
                  if T.Parser.OSC_Data
                    (I + 2 + J - Expected'First) /= Expected (J)
                  then
                     return False;
                  end if;
               end loop;
               return True;
            end Value_Is;
         begin
            while Field_Last < Separator
              and then T.Parser.OSC_Data (Field_Last) /= ':'
            loop
               Field_Last := Field_Last + 1;
            end loop;
            if Field_Last >= I + 3
              and then T.Parser.OSC_Data (I + 1) = '='
            then
               case T.Parser.OSC_Data (I) is
                  when 'p' =>
                     if Value_Is ("body") then
                        Payload_Kind := 'b';
                     elsif Value_Is ("title") then
                        Payload_Kind := 't';
                     elsif Value_Is ("?") then
                        Payload_Kind := '?';
                     else
                        Payload_Kind := 'x';
                     end if;
                  when 'd' =>
                     if Value_Is ("0") then
                        Done := False;
                     elsif Value_Is ("1") then
                        Done := True;
                     else
                        Valid_Metadata := False;
                     end if;
                  when 'e' =>
                     if Value_Is ("0") then
                        Encoded := False;
                     elsif Value_Is ("1") then
                        Encoded := True;
                     else
                        Valid_Metadata := False;
                     end if;
                  when others =>
                     null;
               end case;
            end if;
            I := Field_Last + 1;
         end;
      end loop;
      if not Valid_Metadata or else Payload_Kind in '?' | 'x' then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         T.Notification_Data.Pending := False;
         return;
      end if;
      T.Notification_Data.Kind := Desktop_Notification;
      if Payload_Kind = 'b' then
         if Encoded then
            Decode_Notification_Text
              (T.Notification_Data.Message, Separator + 1, Last, Valid_Payload);
         else
            Set_Notification_Text
              (T.Notification_Data.Message, Separator + 1, Last);
         end if;
      else
         if Encoded then
            Decode_Notification_Text
              (T.Notification_Data.Title, Separator + 1, Last, Valid_Payload);
         else
            Set_Notification_Text
              (T.Notification_Data.Title, Separator + 1, Last);
         end if;
      end if;
      if not Valid_Payload then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         T.Notification_Data.Pending := False;
         return;
      end if;
      T.Notification_Data.Pending :=
        Done
        and then
          (T.Notification_Data.Title.Length > 0
           or else T.Notification_Data.Message.Length > 0);
   end Decode_OSC99;

   procedure Decode_OSC52
     (First : Natural;
      Last  : Natural)
   is
      Enc_First : Natural := 0;
      Out_Len   : Natural := 0;
      Decoder   : Common.Base64.Decoder_State;
      Bytes     : Common.Base64.Decoded_Quantum;
      Byte_Count : Natural := 0;
      Decode_Status : Common.Base64.Decoder_Status;
      Invalid   : Boolean := False;
      Target    : Clipboard_Target := Clipboard_Clipboard;

      function Parse_Target return Boolean is
         Saw_Supported : Boolean := False;
      begin
         if Enc_First <= First + 1 then
            return True;
         end if;

         for I in First .. Enc_First - 2 loop
            case T.Parser.OSC_Data (I) is
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
            Increment_Saturating (T.Diag.Parser_Overflow);
            Invalid := True;
         else
            Out_Len := Out_Len + 1;
            T.Clipboard_Data.Text (Out_Len) :=
              Standard.Character'Val (Value);
         end if;
      end Append_Decoded;

      procedure Append_Output is
      begin
         if Decode_Status = Common.Base64.Invalid_Data then
            Invalid := True;
            return;
         end if;
         for I in 1 .. Byte_Count loop
            Append_Decoded (Natural (Bytes (I)));
            exit when Invalid;
         end loop;
      end Append_Output;
   begin
      for I in First .. Last loop
         if T.Parser.OSC_Data (I) = ';' then
            Enc_First := I + 1;
            exit;
         end if;
      end loop;

      if Enc_First = 0 then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      end if;

      T.Clipboard_Data := (others => <>);
      if not Parse_Target then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      end if;

      if Enc_First = Last and then T.Parser.OSC_Data (Enc_First) = '?' then
         T.Clipboard_Data.Pending := True;
         T.Clipboard_Data.Operation := Clipboard_Query;
         T.Clipboard_Data.Target := Target;
         return;
      end if;

      Common.Base64.Reset
        (Decoder, Allow_Unpadded => True, Allow_Whitespace => True);

      if Enc_First <= Last then
         for I in Enc_First .. Last loop
            Common.Base64.Push
              (Decoder,
               T.Parser.OSC_Data (I),
               Bytes,
               Byte_Count,
               Decode_Status);
            Append_Output;
            exit when Invalid;
         end loop;
      end if;

      if not Invalid then
         Common.Base64.Finish
           (Decoder, Bytes, Byte_Count, Decode_Status);
         Append_Output;
      end if;

      if Invalid then
         T.Clipboard_Data := (others => <>);
         Increment_Saturating (T.Diag.Unsupported_Sequence);
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
               Link.URI (Count) := T.Parser.OSC_Data (I);
            else
               Increment_Saturating (T.Diag.Parser_Overflow);
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
               Link.ID (Count) := T.Parser.OSC_Data (I);
            else
               Increment_Saturating (T.Diag.Parser_Overflow);
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
            while I <= To and then T.Parser.OSC_Data (I) /= ':' loop
               I := I + 1;
            end loop;
            Param_End := I - 1;
            if Param_End >= Param_Start + 3
              and then T.Parser.OSC_Data (Param_Start) = 'i'
              and then T.Parser.OSC_Data (Param_Start + 1) = 'd'
              and then T.Parser.OSC_Data (Param_Start + 2) = '='
            then
               Copy_ID (Param_Start + 3, Param_End);
            end if;
            I := I + 1;
         end loop;
      end Parse_Params;
   begin
      for I in First .. Last loop
         if T.Parser.OSC_Data (I) = ';' then
            URI_First := I + 1;
            exit;
         end if;
      end loop;

      if URI_First = 0 then
         Increment_Saturating (T.Diag.Unsupported_Sequence);
         return;
      elsif URI_First > Last then
         T.Hyperlinks.Current := null;
         return;
      end if;

      Link := (others => <>);
      Link.Active := True;
      Parse_Params (First, URI_First - 2);
      Copy_URI (URI_First, Last);

      if Link.URI_Length = 0 then
         T.Hyperlinks.Current := null;
      else
         T.Hyperlinks.Current := Hyperlink_Store.Intern
           (T.Hyperlinks,
            T.Primary_Cells,
            T.Alt_Cells,
            T.Scrollback_State,
            T.Cols,
            Link);
      end if;
   end Decode_OSC8;
begin
   if T.Parser.OSC_Count < 3 then
      T.Parser.State := Ground;
      return;
   end if;

   for I in 1 .. T.Parser.OSC_Count loop
      if T.Parser.OSC_Data (I) = ';' then
         Payload_First := I + 1;
         exit;
      elsif T.Parser.OSC_Data (I) in '0' .. '9' then
         Command :=
           Append_Decimal_Digit
             (Command,
              Standard.Character'Pos (T.Parser.OSC_Data (I))
                - Standard.Character'Pos ('0'),
              Natural'Last / 2);
      else
         T.Parser.State := Ground;
         return;
      end if;
   end loop;

   if Payload_First = 0 then
      T.Parser.State := Ground;
      return;
   end if;

   if Command in 0 .. 2 then
      Title_Length :=
        Natural'Min
          (T.Parser.OSC_Count - Payload_First + 1,
           Max_Title_Length);
      T.Window_Title := (others => <>);
      T.Window_Title.Length := Title_Length;
      for I in 1 .. Title_Length loop
         T.Window_Title.Text (I) := T.Parser.OSC_Data (Payload_First + I - 1);
      end loop;
   elsif Command = Private_Identity_OSC
     and then T.Parser.OSC_Count - Payload_First + 1 = 1
     and then T.Parser.OSC_Data (Payload_First) = 'q'
   then
      Queue_Identity_Report (T);
   elsif Command = 7 then
      Decode_OSC7 (Payload_First, T.Parser.OSC_Count);
   elsif Command = 8 then
      Decode_OSC8 (Payload_First, T.Parser.OSC_Count);
   elsif Command = 9 then
      Decode_OSC9 (Payload_First, T.Parser.OSC_Count);
   elsif Command = 99 then
      Decode_OSC99 (Payload_First, T.Parser.OSC_Count);
   elsif Command = 133 then
      Decode_OSC133 (Payload_First, T.Parser.OSC_Count);
   elsif Command = 52 then
      Decode_OSC52 (Payload_First, T.Parser.OSC_Count);
   elsif Command = 1337
     and then T.Parser.OSC_Count - Payload_First + 1 = 12
     and then OSC_Slice (T, Payload_First, T.Parser.OSC_Count) = "Capabilities"
   then
      Begin_Response (T);
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_String (T, "]1337;Capabilities=");
      if T.Graphics.Capabilities.ITerm2_Inline_Images
        and then T.Graphics.Capabilities.ITerm2_File_Downloads
      then
         Append_Response_Char (T, 'F');
      end if;
      if T.Graphics.Capabilities.Sixel then
         Append_Response_String (T, "Sx");
      end if;
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_Char (T, '\');
      End_Response (T);
   elsif Command = 1337 and then Payload_Starts_With ("File=") then
      Note_Graphics_Protocol
        (T,
         Graphics_ITerm2,
         T.Parser.OSC_Count - Payload_First + 1,
         OSC_Slice (T, Payload_First, T.Parser.OSC_Count));
   elsif Command = 1337
     and then Payload_Starts_With ("MultipartFile=")
   then
      Graphics_Runtime.Clear_ITerm2_Multipart (T.Graphics);
      T.Graphics.ITerm2_Multipart_Active := True;
      declare
         Accepted : Boolean :=
           Graphics_Runtime.Append_ITerm2_Multipart (T.Graphics, "File=");
      begin
         if Accepted and then Payload_First + 14 <= T.Parser.OSC_Count then
            Accepted := Graphics_Runtime.Append_ITerm2_Multipart
              (T.Graphics,
               OSC_Slice (T, Payload_First + 14, T.Parser.OSC_Count));
         end if;
         if Accepted then
            Accepted := Graphics_Runtime.Append_ITerm2_Multipart
              (T.Graphics, ":");
         end if;
         if not Accepted then
            Graphics_Runtime.Clear_ITerm2_Multipart (T.Graphics);
         end if;
      end;
   elsif Command = 1337
     and then Payload_Starts_With ("FilePart=")
     and then T.Graphics.ITerm2_Multipart_Active
   then
      declare
         Accepted : Boolean := True;
      begin
         if Payload_First + 9 <= T.Parser.OSC_Count then
            Accepted := Graphics_Runtime.Append_ITerm2_Multipart
              (T.Graphics,
               OSC_Slice (T, Payload_First + 9, T.Parser.OSC_Count));
         end if;
         if not Accepted then
            Graphics_Runtime.Clear_ITerm2_Multipart (T.Graphics);
         end if;
      end;
   elsif Command = 1337
     and then T.Graphics.ITerm2_Multipart_Active
     and then T.Parser.OSC_Count - Payload_First + 1 = 7
     and then OSC_Slice (T, Payload_First, T.Parser.OSC_Count) = "FileEnd"
   then
      if T.Graphics.ITerm2_Multipart /= null
        and then T.Graphics.ITerm2_Multipart_Length > 6
      then
         Note_Graphics_Protocol
           (T,
            Graphics_ITerm2,
            T.Graphics.ITerm2_Multipart_Length,
            T.Graphics.ITerm2_Multipart (1 .. T.Graphics.ITerm2_Multipart_Length));
      end if;
      Graphics_Runtime.Clear_ITerm2_Multipart (T.Graphics);
   end if;

   T.Parser.State := Ground;
end Finish_OSC;
