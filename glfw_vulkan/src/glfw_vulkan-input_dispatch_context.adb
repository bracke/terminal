with Ada.Task_Attributes;

package body GLFW_Vulkan.Input_Dispatch_Context is
   package Raw renames GLFW_Vulkan.Raw;
   use type Raw.GLFW_Window_Handle;

   type Window_Array is
     array (Positive range 1 .. Max_Nesting) of Raw.GLFW_Window_Handle;
   type Context is record
      Depth   : Natural range 0 .. Max_Nesting := 0;
      Windows : Window_Array := (others => Raw.Null_Window);
   end record;
   package Contexts is new Ada.Task_Attributes
     (Context, (Depth => 0, Windows => (others => Raw.Null_Window)));

   procedure Enter (Window : Raw.GLFW_Window_Handle) is
      Value : Context := Contexts.Value;
   begin
      if Value.Depth = Max_Nesting then
         raise Program_Error with "GLFW callback nesting limit exceeded";
      end if;
      Value.Depth := Value.Depth + 1;
      Value.Windows (Value.Depth) := Window;
      Contexts.Set_Value (Value);
   end Enter;

   procedure Leave is
      Value : Context := Contexts.Value;
   begin
      if Value.Depth = 0 then
         raise Program_Error with "GLFW callback dispatch stack underflow";
      end if;
      Value.Windows (Value.Depth) := Raw.Null_Window;
      Value.Depth := Value.Depth - 1;
      Contexts.Set_Value (Value);
   end Leave;

   function Depth_For (Window : Raw.GLFW_Window_Handle) return Natural is
      Value  : constant Context := Contexts.Value;
      Result : Natural := 0;
   begin
      for I in 1 .. Value.Depth loop
         if Value.Windows (I) = Window then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Depth_For;

   function Active return Boolean is (Contexts.Value.Depth > 0);
end GLFW_Vulkan.Input_Dispatch_Context;
