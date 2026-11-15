separate (Terminal.Core)
procedure Append_SGR_Status (T : in out Terminal) is
   First : Boolean := True;
   procedure Param (N : Natural) is
   begin
      if First then First := False; else Append_Response_Char (T, ';'); end if;
      Append_Response_Natural (T, N);
   end Param;
   procedure Color_Params
     (C : Color; Base_8, Bright, Selector : Natural) is
   begin
      case C.Kind is
         when Default => null;
         when Indexed =>
            if C.Index <= 7 then Param (Base_8 + C.Index);
            elsif C.Index <= 15 then Param (Bright + C.Index - 8);
            else Param (Selector); Param (5); Param (C.Index);
            end if;
         when RGB =>
            Param (Selector); Param (2); Param (C.R); Param (C.G); Param (C.B);
      end case;
   end Color_Params;
   procedure Extended_Color_Params (C : Color; Selector : Natural) is
   begin
      case C.Kind is
         when Default => null;
         when Indexed => Param (Selector); Param (5); Param (C.Index);
         when RGB =>
            Param (Selector); Param (2); Param (C.R); Param (C.G); Param (C.B);
      end case;
   end Extended_Color_Params;
begin
   if T.Current_Style.Bold then Param (1); end if;
   if T.Current_Style.Faint then Param (2); end if;
   if T.Current_Style.Italic then Param (3); end if;
   if T.Current_Style.Underline then
      if T.Current_Style.Underline_Kind = Underline_Single then
         Param (4);
      else
         if First then First := False; else Append_Response_Char (T, ';'); end if;
         Append_Response_Char (T, '4');
         Append_Response_Char (T, ':');
         Append_Response_Char
           (T,
            (case T.Current_Style.Underline_Kind is
                when Underline_Single => '1', when Underline_Double => '2',
                when Underline_Curly => '3', when Underline_Dotted => '4',
                when Underline_Dashed => '5'));
      end if;
   end if;
   if T.Current_Style.Blink then Param (5); end if;
   if T.Current_Style.Inverse then Param (7); end if;
   if T.Current_Style.Conceal then Param (8); end if;
   if T.Current_Style.Strikethrough then Param (9); end if;
   if T.Current_Style.Overline then Param (53); end if;
   Color_Params (T.Current_Style.Foreground, 30, 90, 38);
   Color_Params (T.Current_Style.Background, 40, 100, 48);
   Extended_Color_Params (T.Current_Style.Underline_Color, 58);
   if First then Param (0); end if;
   Append_Response_Char (T, 'm');
end Append_SGR_Status;
