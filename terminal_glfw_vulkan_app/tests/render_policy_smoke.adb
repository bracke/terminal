with AUnit.Assertions;

with Terminal.App.Render_Policy;
with Terminal.Core;

procedure Render_Policy_Smoke is
   use AUnit.Assertions;

   Modes : Terminal.Core.Mode_Snapshot;
begin
   Assert
     (not Terminal.App.Render_Policy.Should_Defer_Render
        (Modes, 0, False, False),
      "normal mode should render");

   Modes.Synchronized_Update := True;
   Assert
     (Terminal.App.Render_Policy.Should_Defer_Render
        (Modes, 0, False, False),
      "synchronized terminal updates should defer live renders");

   Assert
     (not Terminal.App.Render_Policy.Should_Defer_Render
        (Modes, 1, False, False),
      "scrollback view should remain locally drawable");

   Assert
     (not Terminal.App.Render_Policy.Should_Defer_Render
        (Modes, 0, True, False),
      "selection redraw should remain locally drawable");

   Assert
     (not Terminal.App.Render_Policy.Should_Defer_Render
        (Modes, 0, False, True),
      "explicit local redraw should not be deferred");
end Render_Policy_Smoke;
