--  Who this terminal says it is: in TERM_PROGRAM and TERM_PROGRAM_VERSION,
--  in its XTVERSION answer, and in its answer to the private identity query.
package Terminal.Common.Identity is
   pragma Pure;

   Program_Name    : constant String := "bracke-terminal";
   Program_Version : constant String := "0.1.0-dev";

   --  The version of the private identity exchange, OSC 7701.
   Identity_Protocol_Version : constant := 1;
end Terminal.Common.Identity;
