with Terminal.Common.Graphics_Limits;

package Terminal.Core.Parser_Limits is
   Max_OSC_Length : constant Positive :=
     Common.Graphics_Limits.Max_OSC_Bytes;
   Max_Escape_Length : constant Positive :=
     Common.Graphics_Limits.Max_Escape_Preview_Bytes;
end Terminal.Core.Parser_Limits;
