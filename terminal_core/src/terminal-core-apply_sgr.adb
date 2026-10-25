separate (Terminal.Core)
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
