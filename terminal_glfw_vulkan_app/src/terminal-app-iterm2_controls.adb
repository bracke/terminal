package body Terminal.App.ITerm2_Controls is
   function Kind (Name : String; Found : out Boolean) return Field_Kind is
   begin
      Found := True;
      if Name = "inline" then
         return Inline_Field;
      elsif Name = "name" then
         return Name_Field;
      elsif Name = "width" then
         return Width_Field;
      elsif Name = "height" then
         return Height_Field;
      elsif Name = "preserveAspectRatio" then
         return Preserve_Aspect_Field;
      elsif Name = "doNotMoveCursor" then
         return Do_Not_Move_Field;
      elsif Name = "size" then
         return Size_Field;
      else
         Found := False;
         return Inline_Field;
      end if;
   end Kind;

   procedure Parse (Text : String; Result : out Parsed_Controls) is
      Header_Last : Natural := Text'Last;
      Position    : Natural;
   begin
      Result := (others => <>);
      if Text'Length < 5
        or else Text (Text'First .. Text'First + 4) /= "File="
      then
         return;
      end if;
      Result.Is_Recognized := True;
      for I in Text'Range loop
         if Text (I) = ':' then
            Header_Last := I - 1;
            Result.Contains_Data := I < Text'Last;
            --  Preserve the delimiter position even for a valid empty FILE
            --  payload. Has_Data deliberately continues to describe whether
            --  at least one encoded byte follows it.
            Result.Payload_First := I + 1;
            exit;
         end if;
      end loop;

      Position := Text'First + 5;
      while Position <= Header_Last loop
         declare
            Stop : Natural := Position;
            Eq   : Natural := 0;
         begin
            while Stop <= Header_Last
              and then Text (Stop) /= ','
              and then Text (Stop) /= ';'
            loop
               if Text (Stop) = '=' then
                  if Eq = 0 then
                     Eq := Stop;
                  end if;
               end if;
               Stop := Stop + 1;
            end loop;
            if Stop = Position or else Eq <= Position then
               Result.Is_Valid := False;
            else
               declare
                  Found : Boolean;
                  Field : constant Field_Kind :=
                    Kind (Text (Position .. Eq - 1), Found);
               begin
                  if Found then
                     if Eq = Stop - 1 then
                        Result.Is_Valid := False;
                     end if;
                     declare
                        Extra_Equals : Boolean := False;
                        Invalid_Name_Padding : Boolean := False;
                        Padding_Started : Boolean := False;
                     begin
                        for I in Eq + 1 .. Stop - 1 loop
                           if Text (I) = '=' then
                              Extra_Equals := True;
                              Padding_Started := True;
                           elsif Padding_Started then
                              Invalid_Name_Padding := True;
                           end if;
                        end loop;
                        if (Field /= Name_Field and then Extra_Equals)
                          or else
                            (Field = Name_Field and then Invalid_Name_Padding)
                        then
                           Result.Is_Valid := False;
                        end if;
                     end;
                     if Result.Fields (Field).Present then
                        Result.Is_Valid := False;
                     else
                        Result.Fields (Field) :=
                          (Present => True, First => Eq + 1, Last => Stop - 1);
                     end if;
                  end if;
               end;
            end if;
            Position := Stop + 1;
         end;
      end loop;
      if Header_Last >= Text'First + 5
        and then Text (Header_Last) in ',' | ';'
      then
         Result.Is_Valid := False;
      end if;
   end Parse;

   function Recognized (Result : Parsed_Controls) return Boolean is
     (Result.Is_Recognized);

   function Valid (Result : Parsed_Controls) return Boolean is
     (Result.Is_Valid);

   function Has_Data (Result : Parsed_Controls) return Boolean is
     (Result.Contains_Data);

   function Data_First (Result : Parsed_Controls) return Natural is
     (Result.Payload_First);

   function Value
     (Text   : String;
      Result : Parsed_Controls;
      Field  : Field_Kind) return String is
   begin
      if not Result.Fields (Field).Present then
         return "";
      end if;
      return Text
        (Result.Fields (Field).First .. Result.Fields (Field).Last);
   end Value;
end Terminal.App.ITerm2_Controls;
