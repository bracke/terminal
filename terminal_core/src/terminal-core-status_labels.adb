with Terminal.Common.Counters;
with Terminal.Common.Status;

package body Terminal.Core.Status_Labels is
   function Bounded (Label : String) return String is
   begin
      if Label'Length <= Max_Status_Label_Length then
         return Label;
      end if;
      return Label (Label'First .. Label'First + Max_Status_Label_Length - 4)
        & "...";
   end Bounded;

   function Initialize_Label (Status : Initialize_Status) return String is
     (case Status is
         when Ok                       => "Initialize: Ok",
         when Invalid_Size             => "Initialize: Invalid Size",
         when Invalid_Scrollback_Limit => "Initialize: Invalid Scrollback Limit",
         when Allocation_Failed        => "Initialize: Allocation Failed");

   function Feed_Label (Status : Feed_Status) return String is
     (case Status is
         when Ok               => "Feed: Ok",
         when Parser_Recovered => "Feed: Parser Recovered",
         when Parser_Overflow  => "Feed: Parser Overflow",
         when Invalid_State    => "Feed: Invalid State");

   function Diagnostics_Label
     (Diagnostics : Diagnostic_Snapshot) return String
   is
      Total : Natural := 0;
      procedure Add (Value : Natural) is
      begin
         Common.Counters.Add_Saturating (Total, Value);
      end Add;
      function Image (Value : Natural) return String renames
        Common.Status.Trimmed_Natural;
   begin
      Add (Diagnostics.Malformed_UTF8);
      Add (Diagnostics.Ignored_Escape);
      Add (Diagnostics.Parser_Overflow);
      Add (Diagnostics.Queue_Overflow);
      Add (Diagnostics.Unsupported_Sequence);
      Add (Diagnostics.Text_Cluster_Overflow);
      Add (Diagnostics.Graphics_Commands_Received);
      Add (Diagnostics.Multiplexer_Passthrough);
      if Total = 0 then
         return "Diagnostics: clean";
      end if;
      return Bounded
        ("Diagnostics: issues=" & Image (Total)
         & " utf8=" & Image (Diagnostics.Malformed_UTF8)
         & " esc=" & Image (Diagnostics.Ignored_Escape)
         & " parse=" & Image (Diagnostics.Parser_Overflow)
         & " queue=" & Image (Diagnostics.Queue_Overflow)
         & " unsup=" & Image (Diagnostics.Unsupported_Sequence)
         & " gfx=" & Image (Diagnostics.Graphics_Commands_Received)
         & " mux=" & Image (Diagnostics.Multiplexer_Passthrough));
   end Diagnostics_Label;
end Terminal.Core.Status_Labels;
