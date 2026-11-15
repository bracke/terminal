separate (Terminal.Core.Parser_Execution)
procedure Decode_Printable (T : in out Terminal; B : Common.Bytes.Byte) is
   V : constant Natural := Natural (B);

   function Charset_For (Slot : Charset_Slot) return Charset_Kind is
   begin
      case Slot is
         when G0 => return T.G0_Charset;
         when G1 => return T.G1_Charset;
         when G2 => return T.G2_Charset;
         when G3 => return T.G3_Charset;
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
         when 16#84# => Index_Control (T);
         when 16#85# => Next_Line_Control (T);
         when 16#88# => Horizontal_Tab_Set (T);
         when 16#8C# => Reset_Terminal (T);
         when 16#8D# => Reverse_Index_Control (T);
         when 16#8E# =>
            T.Single_Shift_Charset := G2;
            T.Parser.State := Single_Shift;
         when 16#8F# =>
            T.Single_Shift_Charset := G3;
            T.Parser.State := Single_Shift;
         when 16#90# => Start_Ignored_String (T, Is_DCS => True);
         when 16#98# | 16#9E# => Start_Ignored_String (T, Is_DCS => False);
         when 16#9F# =>
            Start_Ignored_String (T, Is_DCS => False, Is_APC => True);
         when 16#9B# =>
            Clear_CSI (T);
            T.Parser.State := CSI;
         when 16#9C# => null;
         when 16#9D# =>
            T.Parser.OSC_Count := 0;
            T.Parser.State := OSC;
         when others => Put_Code_Point (T, Common.Code_Point (CP));
      end case;
   end Put_Decoded_Code_Point;
begin
   if T.Parser.UTF8_Need = 0 then
      if V < 16#80# then
         Put_Mapped_ASCII (T.Active_Charset);
      elsif V in 16#C2# .. 16#DF# then
         T.Parser.UTF8_Need := 1;
         T.Parser.UTF8_Seen := 0;
         T.Parser.UTF8_Accum := V mod 32;
         T.Parser.UTF8_Min := 16#80#;
      elsif V in 16#E0# .. 16#EF# then
         T.Parser.UTF8_Need := 2;
         T.Parser.UTF8_Seen := 0;
         T.Parser.UTF8_Accum := V mod 16;
         T.Parser.UTF8_Min := 16#800#;
      elsif V in 16#F0# .. 16#F4# then
         T.Parser.UTF8_Need := 3;
         T.Parser.UTF8_Seen := 0;
         T.Parser.UTF8_Accum := V mod 8;
         T.Parser.UTF8_Min := 16#10000#;
      else
         Emit_UTF8_Replacement (T);
      end if;
   elsif V in 16#80# .. 16#BF# then
      T.Parser.UTF8_Accum := T.Parser.UTF8_Accum * 64 + (V mod 64);
      T.Parser.UTF8_Seen := T.Parser.UTF8_Seen + 1;
      if T.Parser.UTF8_Seen = T.Parser.UTF8_Need then
         if T.Parser.UTF8_Accum < T.Parser.UTF8_Min
           or else T.Parser.UTF8_Accum in 16#D800# .. 16#DFFF#
           or else T.Parser.UTF8_Accum > 16#10FFFF#
         then
            Emit_UTF8_Replacement (T);
         else
            Put_Decoded_Code_Point (T.Parser.UTF8_Accum);
            T.Parser.UTF8_Need := 0;
            T.Parser.UTF8_Seen := 0;
            T.Parser.UTF8_Accum := 0;
            T.Parser.UTF8_Min := 0;
         end if;
      end if;
   else
      Emit_UTF8_Replacement (T);
      Decode_Printable (T, B);
   end if;
end Decode_Printable;
