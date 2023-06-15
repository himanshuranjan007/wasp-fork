module Wasp.Cli.Command.AI.GenerateNewProject.Skeleton
  ( generateAndWriteProjectSkeleton,
  )
where

import Control.Arrow (first)
import Control.Monad.IO.Class (liftIO)
import qualified Data.Text as T
import NeatInterpolation (trimming)
import qualified StrongPath as SP
import Wasp.Cli.Command.AI.CodeAgent (CodeAgent, writeNewFile)
import Wasp.Cli.Command.AI.GenerateNewProject.Common (AuthProvider (..), File, NewProjectDetails (..))
import Wasp.Cli.Command.AI.GenerateNewProject.Plan (PlanRule)
import Wasp.Cli.Command.CreateNewProject (readCoreWaspProjectFiles)
import qualified Wasp.Version

generateAndWriteProjectSkeleton :: NewProjectDetails -> CodeAgent (FilePath, [PlanRule])
generateAndWriteProjectSkeleton newProjectDetails = do
  coreFiles <- liftIO $ map (first SP.fromRelFile) <$> readCoreWaspProjectFiles
  mapM_ writeNewFile coreFiles

  let (waspFile@(waspFilePath, _), planRules) = generateBaseWaspFile newProjectDetails
  writeNewFile waspFile

  case _projectAuth newProjectDetails of
    UsernameAndPassword -> do
      writeNewFile generateLoginJsPage
      writeNewFile generateSignupJsPage

  writeNewFile generateDotEnvServerFile

  return (waspFilePath, planRules)

generateBaseWaspFile :: NewProjectDetails -> (File, [PlanRule])
generateBaseWaspFile newProjectDetails = ((path, content), planRules)
  where
    path = "main.wasp"
    appName = T.pack $ _projectAppName newProjectDetails
    appTitle = appName
    waspVersion = T.pack $ show Wasp.Version.waspVersion
    (appAuth, authPlanRules) = case _projectAuth newProjectDetails of
      -- NOTE: We assume two things here:
      --   - that there will be a page with route "/".
      --   - that there will be a User entity with 'id', 'username' and 'password'.
      -- We later that those will be added to Plan.
      UsernameAndPassword ->
        ( [trimming|
            auth: {
              userEntity: User,
              methods: {
                usernameAndPassword: {}
              },
              onAuthFailedRedirectTo: "/login",
              onAuthSucceededRedirectTo: "/"
            },
        |],
          [ "Generate a User entity, with at least the following fields: 'id', 'username', 'password'.",
            "There should be a page with route path \"/\"."
          ]
        )
    planRules = authPlanRules <> ["Don't generate the Login or Signup page."]
    content =
      [trimming|
        app ${appName} {
          wasp: {
            version: "^${waspVersion}"
          },
          title: ${appTitle},
          ${appAuth}
        }

        route LoginRoute { path: "/login", to: LoginPage }
        page LoginPage {
          component: import Login from "@client/Login.jsx"
        }
        route SignupRoute { path: "/signup", to: SignupPage }
        page SignupPage {
          component: import Signup from "@client/Signup.jsx"
        }
      |]

generateLoginJsPage :: File
generateLoginJsPage =
  ( "src/client/Login.jsx",
    [trimming|
      import React from 'react';
      import { LoginForm } from '@wasp/auth/forms/Login';

      export default function Login() {
        return (
          <div>
            <h1>Login</h1>
            <LoginForm />
          </div>
        );
      }
    |]
  )

generateSignupJsPage :: File
generateSignupJsPage =
  ( "src/client/Signup.jsx",
    [trimming|
      import React from 'react';
      import { SignupForm } from '@wasp/auth/forms/Signup';

      export default function Signup() {
        return (
          <div>
            <h1>Signup</h1>
            <SignupForm />
          </div>
        );
      }
    |]
  )

generateDotEnvServerFile :: File
generateDotEnvServerFile =
  ( ".env.server",
    [trimming|
      // Here you can define env vars to pass to the server.
      // MY_ENV_VAR=foobar
    |]
  )