separate (Terminal.Core)
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
