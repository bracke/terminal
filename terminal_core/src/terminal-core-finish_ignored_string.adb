separate (Terminal.Core)
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
      Begin_Response (T);
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
      End_Response (T);
   end if;

   T.Ignored_String_Is_DCS := False;
   T.Ignored_String_Is_APC := False;
   Clear_Graphics_Transfer (T);
   T.State := Ground;
end Finish_Ignored_String;
