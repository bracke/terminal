separate (Terminal.App.Graphics)
   function Header_Text
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol;
      Text     : String) return Graphics_Header
   is
      Result : Graphics_Header;
   begin
      if Text = "" then
         return Result;
      end if;

      case Protocol is
         when Terminal.Core.Sixel_Graphics =>
            Result.Recognized := Text (Text'First) = 'q'
              or else Text (Text'First) in '0' .. '9'
              or else Text (Text'First) = '?';
            Result.Has_Data := Text'Length > 0;
            if Result.Recognized then
               declare
                  Info : constant Sixel_Info := Analyze_Sixel (Text);
               begin
                  Result.Raw_Format := (if Info.Width > 0 then 32 else 0);
                  Result.Pixel_Width := Info.Width;
                  Result.Pixel_Height := Info.Height;
                  Result.Sixel_Transparent := Info.Transparent;
               end;
            end if;
         when Terminal.Core.Kitty_Graphics =>
            if Text (Text'First) /= 'G' then
               return Result;
            end if;
            Result.Recognized := True;
            declare
               Header_Last : Natural := Text'Last;
            begin
               for I in Text'Range loop
                  if Text (I) = ';' then
                     Header_Last := I - 1;
                     Result.Has_Data := I < Text'Last;
                     exit;
                  end if;
               end loop;
               if Header_Last > Text'First then
                  declare
                     Params : constant String :=
                       Text (Text'First + 1 .. Header_Last);
                     Action : constant String := Field_Value (Params, "a");
                  begin
                     Result.Kitty_Control_Data_Valid :=
                       Valid_Kitty_Control_Data (Params);
                     Result.Kitty_Action :=
                       (if Action'Length > 0 then Action (Action'First)
                        else 't');
                     declare
                        Transmission : constant String :=
                          Field_Value (Params, "t");
                        Compression : constant String :=
                          Field_Value (Params, "o");
                        Delete_Selector : constant String :=
                          Field_Value (Params, "d");
                     begin
                        Result.Kitty_Transmission :=
                          (if Transmission'Length > 0
                           then Transmission (Transmission'First)
                           else ASCII.NUL);
                        Result.Kitty_Transmission_Specified :=
                          Transmission'Length > 0;
                        Result.Kitty_Transmission_Valid :=
                          Transmission'Length = 0
                          or else
                            (Transmission'Length = 1
                             and then Transmission (Transmission'First)
                               in 'd' | 'f' | 't' | 's');
                        Result.Kitty_Compression :=
                          (if Compression'Length > 0
                           then Compression (Compression'First)
                           else ASCII.NUL);
                        Result.Kitty_Compression_Specified :=
                          Compression'Length > 0;
                        Result.Kitty_Compression_Valid :=
                          Compression'Length = 0 or else Compression = "z";
                        Result.Kitty_Delete :=
                          (if Delete_Selector'Length > 0
                           then Delete_Selector (Delete_Selector'First)
                           else ASCII.NUL);
                     end;
                     Result.Kitty_ID :=
                       Parse_Graphics_ID (Field_Value (Params, "i"));
                     Result.Kitty_Image_Number :=
                       Parse_Graphics_ID (Field_Value (Params, "I"));
                     Result.Kitty_Placement_ID :=
                       Parse_Graphics_ID (Field_Value (Params, "p"));
                     Result.Kitty_Quiet :=
                       Parse_Natural (Field_Value (Params, "q"));
                     Result.Kitty_Usage_Hint :=
                       Parse_Natural (Field_Value (Params, "N"));
                     declare
                        Format_Text : constant String :=
                          Field_Value (Params, "f");
                     begin
                        Result.Kitty_Format :=
                          (if Format_Text'Length = 0
                           then 32
                           else Parse_Natural (Format_Text));
                     end;
                     declare
                        More : constant String := Field_Value (Params, "m");
                     begin
                        Result.Kitty_More_Specified := More'Length > 0;
                        Result.Kitty_More_Valid :=
                          More'Length = 0 or else More = "0" or else More = "1";
                        Result.Kitty_More := More = "1";
                     end;
                     Result.Raw_Format := Result.Kitty_Format;
                     Result.Pixel_Width :=
                       Parse_Natural (Field_Value (Params, "s"));
                     Result.Pixel_Height :=
                       Parse_Natural (Field_Value (Params, "v"));
                     declare
                        Size_Text : constant String := Field_Value (Params, "S");
                        Offset_Text : constant String := Field_Value (Params, "O");
                     begin
                        Result.Kitty_Data_Size_Specified := Size_Text'Length > 0;
                        Result.Kitty_Data_Size_Valid :=
                          Size_Text'Length = 0 or else Valid_Natural_Text (Size_Text);
                        Result.Kitty_Data_Size := Parse_Natural (Size_Text);
                        Result.Kitty_Data_Offset_Specified := Offset_Text'Length > 0;
                        Result.Kitty_Data_Offset_Valid :=
                          Offset_Text'Length = 0
                          or else Valid_Natural_Text (Offset_Text);
                        Result.Kitty_Data_Offset := Parse_Natural (Offset_Text);
                     end;
                     Result.Kitty_Source_X :=
                       Parse_Natural (Field_Value (Params, "x"));
                     Result.Kitty_Source_Y :=
                       Parse_Natural (Field_Value (Params, "y"));
                     Result.Kitty_Delete_Range_First :=
                       Parse_Graphics_ID (Field_Value (Params, "x"));
                     Result.Kitty_Delete_Range_Last :=
                       Parse_Graphics_ID (Field_Value (Params, "y"));
                     Result.Kitty_Source_Width :=
                       Parse_Natural (Field_Value (Params, "w"));
                     Result.Kitty_Source_Height :=
                       Parse_Natural (Field_Value (Params, "h"));
                     Result.Kitty_Cell_X :=
                       Parse_Natural (Field_Value (Params, "X"));
                     Result.Kitty_Cell_Y :=
                       Parse_Natural (Field_Value (Params, "Y"));
                     declare
                        X_Source : constant String := Field_Value (Params, "x");
                        Y_Source : constant String := Field_Value (Params, "y");
                        Width    : constant String := Field_Value (Params, "w");
                        Height   : constant String := Field_Value (Params, "h");
                        X_Cell   : constant String := Field_Value (Params, "X");
                        Y_Cell   : constant String := Field_Value (Params, "Y");
                     begin
                        Result.Kitty_Geometry_Controls_Valid :=
                          (X_Source'Length = 0
                           or else Valid_Natural_Text (X_Source))
                          and then
                            (Y_Source'Length = 0
                             or else Valid_Natural_Text (Y_Source))
                          and then
                            (Width'Length = 0
                             or else Valid_Natural_Text (Width))
                          and then
                            (Height'Length = 0
                             or else Valid_Natural_Text (Height))
                          and then
                            (X_Cell'Length = 0
                             or else Valid_Natural_Text (X_Cell))
                          and then
                            (Y_Cell'Length = 0
                             or else Valid_Natural_Text (Y_Cell));
                     end;
                     Result.Kitty_Z_Index :=
                       Parse_Integer (Field_Value (Params, "z"));
                     Result.Kitty_No_Cursor_Move :=
                       Field_Value (Params, "C") = "1";
                     Result.Kitty_Virtual_Placement :=
                       Field_Value (Params, "U") = "1";
                     Result.Kitty_Parent_ID :=
                       Parse_Graphics_ID (Field_Value (Params, "P"));
                     Result.Kitty_Parent_Placement_ID :=
                       Parse_Graphics_ID (Field_Value (Params, "Q"));
                     Result.Kitty_Parent_Offset_X :=
                       Parse_Integer (Field_Value (Params, "H"));
                     Result.Kitty_Parent_Offset_Y :=
                       Parse_Integer (Field_Value (Params, "V"));
                     if Result.Kitty_Action = 'f' then
                        Result.Kitty_Frame_Number :=
                          Parse_Natural (Field_Value (Params, "r"));
                        Result.Kitty_Base_Frame :=
                          Parse_Natural (Field_Value (Params, "c"));
                        Result.Kitty_Frame_Gap :=
                          Parse_Integer (Field_Value (Params, "z"));
                        Result.Kitty_Composition_Mode :=
                          Parse_Natural (Field_Value (Params, "X"));
                        Result.Kitty_Background_Color :=
                          Parse_Graphics_ID (Field_Value (Params, "Y"));
                     elsif Result.Kitty_Action = 'a' then
                        Result.Kitty_Animation_State := Result.Pixel_Width;
                        Result.Kitty_Frame_Number :=
                          Parse_Natural (Field_Value (Params, "r"));
                        Result.Kitty_Base_Frame :=
                          Parse_Natural (Field_Value (Params, "c"));
                        Result.Kitty_Frame_Gap :=
                          Parse_Integer (Field_Value (Params, "z"));
                        Result.Kitty_Loop_Count := Result.Pixel_Height;
                     elsif Result.Kitty_Action = 'c' then
                        Result.Kitty_Frame_Number :=
                          Parse_Natural (Field_Value (Params, "c"));
                        Result.Kitty_Base_Frame :=
                          Parse_Natural (Field_Value (Params, "r"));
                        Result.Kitty_Composition_Mode :=
                          Parse_Natural (Field_Value (Params, "C"));
                     end if;
                     declare
                        Columns : constant String := Field_Value (Params, "c");
                        Rows    : constant String := Field_Value (Params, "r");
                        Column_Value : constant Natural := Parse_Natural (Columns);
                        Row_Value    : constant Natural := Parse_Natural (Rows);
                     begin
                        Result.Kitty_Columns_Specified := Columns'Length > 0;
                        Result.Kitty_Rows_Specified := Rows'Length > 0;
                        Result.Kitty_Columns_Valid :=
                          Columns'Length = 0 or else Column_Value > 0;
                        Result.Kitty_Rows_Valid :=
                          Rows'Length = 0 or else Row_Value > 0;
                        if Result.Kitty_Columns_Specified
                          and then Result.Kitty_Columns_Valid
                        then
                           Result.Placeholder_Cols := Positive (Column_Value);
                        else
                           Result.Placeholder_Cols := 6;
                        end if;
                        if Result.Kitty_Rows_Specified
                          and then Result.Kitty_Rows_Valid
                        then
                           Result.Placeholder_Rows := Positive (Row_Value);
                        else
                           Result.Placeholder_Rows := 3;
                        end if;
                     end;
                     declare
                        C_Text : constant String := Field_Value (Params, "C");
                        U_Text : constant String := Field_Value (Params, "U");
                        X_Text : constant String := Field_Value (Params, "X");
                        State_Text : constant String := Field_Value (Params, "s");
                        Frame_C_Text : constant String := Field_Value (Params, "c");
                        Frame_R_Text : constant String := Field_Value (Params, "r");
                        Delete_X_Text : constant String := Field_Value (Params, "x");
                        Delete_Y_Text : constant String := Field_Value (Params, "y");
                        Has_Identity : constant Boolean :=
                          (Result.Kitty_ID /= 0)
                          xor (Result.Kitty_Image_Number /= 0);
                     begin
                        Result.Kitty_Delete_Controls_Valid :=
                          (case Result.Kitty_Delete is
                             when ASCII.NUL | 'a' | 'A' | 'c' | 'C'
                                | 'z' | 'Z' => True,
                             when 'i' | 'I' =>
                                Result.Kitty_ID /= 0
                                and then Result.Kitty_Image_Number = 0,
                             when 'n' | 'N' =>
                                Result.Kitty_Image_Number /= 0
                                and then Result.Kitty_ID = 0,
                             when 'f' | 'F' => Has_Identity,
                             when 'p' | 'P' | 'q' | 'Q' =>
                                Valid_Natural_Text (Delete_X_Text)
                                and then Valid_Natural_Text (Delete_Y_Text)
                                and then Parse_Natural (Delete_X_Text) > 0
                                and then Parse_Natural (Delete_Y_Text) > 0,
                             when 'x' | 'X' =>
                                Valid_Natural_Text (Delete_X_Text)
                                and then Parse_Natural (Delete_X_Text) > 0,
                             when 'y' | 'Y' =>
                                Valid_Natural_Text (Delete_Y_Text)
                                and then Parse_Natural (Delete_Y_Text) > 0,
                             when 'r' | 'R' =>
                                Delete_X_Text'Length > 0
                                and then Delete_Y_Text'Length > 0
                                and then Valid_Graphics_ID_Text (Delete_X_Text)
                                and then Valid_Graphics_ID_Text (Delete_Y_Text)
                                and then Result.Kitty_Delete_Range_Last >=
                                  Result.Kitty_Delete_Range_First,
                             when others => False);
                        Result.Kitty_Action_Controls_Valid :=
                          Result.Kitty_Control_Data_Valid
                          and then not
                            (Result.Kitty_ID /= 0
                             and then Result.Kitty_Image_Number /= 0)
                          and then
                            (case Result.Kitty_Action is
                               when 't' | 'T' => Result.Has_Data,
                               when 'q' =>
                                  Result.Has_Data
                                  and then Result.Kitty_ID /= 0
                                  and then Result.Kitty_Image_Number = 0,
                               when 'p' =>
                                  not Result.Has_Data and then Has_Identity,
                               when 'd' =>
                                  not Result.Has_Data
                                  and then Result.Kitty_Delete_Controls_Valid,
                               when 'f' =>
                                  Result.Has_Data
                                  and then Has_Identity
                                  and then
                                    (X_Text'Length = 0
                                     or else X_Text = "0"
                                     or else X_Text = "1"),
                               when 'a' =>
                                  not Result.Has_Data
                                  and then Has_Identity
                                  and then
                                    (State_Text'Length = 0
                                     or else State_Text = "1"
                                     or else State_Text = "2"
                                     or else State_Text = "3"),
                               when 'c' =>
                                  not Result.Has_Data
                                  and then Has_Identity
                                  and then Parse_Natural (Frame_C_Text) > 0
                                  and then Parse_Natural (Frame_R_Text) > 0
                                  and then
                                    (C_Text'Length = 0
                                     or else C_Text = "0"
                                     or else C_Text = "1"),
                               when others => False)
                          and then
                            (if Result.Kitty_Action in 'T' | 'p'
                             then
                               (C_Text'Length = 0
                                or else C_Text = "0"
                                or else C_Text = "1")
                               and then
                                 (U_Text'Length = 0
                                  or else U_Text = "0"
                                  or else U_Text = "1")
                             else True);
                     end;
                  end;
               end if;
            end;
         when Terminal.Core.ITerm2_Graphics =>
            if Text'Length < 5 or else Text (Text'First .. Text'First + 4) /= "File=" then
               return Result;
            end if;
            Result.Recognized := True;
            declare
               Header_Last : Natural := Text'Last;
            begin
               for I in Text'Range loop
                  if Text (I) = ':' then
                     Header_Last := I - 1;
                     Result.Has_Data := I < Text'Last;
                     exit;
                  end if;
               end loop;
               if Header_Last >= Text'First + 5 then
                  declare
                     Params : constant String := Text (Text'First + 5 .. Header_Last);
                     Inline : constant String := Field_Value (Params, "inline");
                     Name   : constant String := Field_Value (Params, "name");
                     Width  : constant String := Field_Value (Params, "width");
                     Height : constant String := Field_Value (Params, "height");
                     Preserve : constant String :=
                       Field_Value (Params, "preserveAspectRatio");
                     Do_Not_Move : constant String :=
                       Field_Value (Params, "doNotMoveCursor");
                     Size_Text : constant String := Field_Value (Params, "size");

                     procedure Parse_Size
                       (Value     : String;
                        Specified : out Boolean;
                        Valid     : out Boolean;
                        Number    : out Natural;
                        Unit      : out ITerm2_Size_Unit)
                     is
                        Digits_Last : Natural := 0;
                     begin
                        Specified := Value'Length > 0;
                        Valid := True;
                        Number := 0;
                        Unit := ITerm2_Auto;
                        if Value'Length = 0 or else Value = "auto" then
                           return;
                        elsif Value'Length >= 3
                          and then Value (Value'Last - 1 .. Value'Last) = "px"
                        then
                           Unit := ITerm2_Pixels;
                           Digits_Last := Value'Last - 2;
                        elsif Value (Value'Last) = '%' then
                           Unit := ITerm2_Percent;
                           Digits_Last := Value'Last - 1;
                        else
                           Unit := ITerm2_Cells;
                           Digits_Last := Value'Last;
                        end if;
                        if Digits_Last < Value'First then
                           Valid := False;
                           return;
                        end if;
                        declare
                           Numeric_Text : constant String :=
                             Value (Value'First .. Digits_Last);
                        begin
                           Valid := Valid_Natural_Text (Numeric_Text);
                           Number := Parse_Natural (Numeric_Text);
                           Valid := Valid and then Number > 0;
                        end;
                     end Parse_Size;
                  begin
                     Result.ITerm2_Inline := Inline = "1";
                     Result.ITerm2_Declared_Size_Valid :=
                       Size_Text'Length = 0
                       or else Valid_Natural_Text (Size_Text);
                     Result.ITerm2_Control_Data_Valid :=
                       (Inline'Length = 0 or else Inline in "0" | "1")
                       and then
                         (Preserve'Length = 0
                          or else Preserve in "0" | "1")
                       and then
                         (Do_Not_Move'Length = 0
                          or else Do_Not_Move in "0" | "1")
                       and then Result.ITerm2_Declared_Size_Valid;
                     Result.ITerm2_Name_Length := Name'Length;
                     Result.ITerm2_Declared_Size :=
                       Parse_Natural (Size_Text);
                     Result.ITerm2_Preserve_Aspect_Ratio := Preserve /= "0";
                     Result.ITerm2_Do_Not_Move_Cursor := Do_Not_Move = "1";
                     Parse_Size
                       (Width,
                        Result.ITerm2_Width_Specified,
                        Result.ITerm2_Width_Valid,
                        Result.ITerm2_Width_Value,
                        Result.ITerm2_Width_Unit);
                     Parse_Size
                       (Height,
                        Result.ITerm2_Height_Specified,
                        Result.ITerm2_Height_Valid,
                        Result.ITerm2_Height_Value,
                        Result.ITerm2_Height_Unit);
                     if Result.ITerm2_Width_Unit = ITerm2_Cells
                       and then Result.ITerm2_Width_Valid
                     then
                        Result.Placeholder_Cols := Clamp_Positive
                          (Result.ITerm2_Width_Value, 6, 80);
                     end if;
                     if Result.ITerm2_Height_Unit = ITerm2_Cells
                       and then Result.ITerm2_Height_Valid
                     then
                        Result.Placeholder_Rows := Clamp_Positive
                          (Result.ITerm2_Height_Value, 3, 40);
                     end if;
                  end;
               end if;
            end;
         when Terminal.Core.No_Graphics =>
            null;
      end case;

      return Result;
   end Header_Text;

