<?php

namespace App\Controller;

use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\Security\Http\Authentication\AuthenticationUtils;
use App\Form\RegistrationFormType;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use App\Form\ForgotPasswordFormType;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Symfony\Component\Routing\Generator\UrlGeneratorInterface;

class RpgController extends AbstractController
{
    #[Route('/', name: 'app_rpg')]
    public function index(): Response
    {
        $character = [
            'name' => 'John',
            'level' => 5,
            'hp' => 100,
            'mana' => 50,
            'attack' => 10,
            'defense' => 5,
        ];

        return $this->render('rpg/index.html.twig', [
            'character' => $character,
        ]);
    }

    #[Route('/login', name: 'app_login')]
    public function login(AuthenticationUtils $authenticationUtils): Response
    {
        return $this->render('login/login.html.twig', [
            'last_username' => $authenticationUtils->getLastUsername(),
            'error' => $authenticationUtils->getLastAuthenticationError(),
        ]);
    }

    #[Route('/logout', name: 'app_logout')]
    public function logout(): void
    {
        throw new \LogicException('Intercepted by firewall.');
    }

    #[Route('/forgot-password', name: 'app_forgot_password')]
    public function forgotPassword(
        Request $request,
        EntityManagerInterface $entityManager,
        MailerInterface $mailer
    ): Response {

        $form = $this->createForm(ForgotPasswordFormType::class);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {

            $email = $form->get('email')->getData();

            $user = $entityManager
                ->getRepository(User::class)
                ->findOneBy(['email' => $email]);

            if (!$user) {
                $this->addFlash('reset_password_error', 'No hero found with this email.');
                return $this->redirectToRoute('app_forgot_password');
            }

            // génération d'un token
            $token = bin2hex(random_bytes(32));

            // lien de reset
            $resetLink = $this->generateUrl(
                'app_reset_password',
                ['token' => $token],
                UrlGeneratorInterface::ABSOLUTE_URL
            );

            // email
            $message = (new Email())
                ->from('tower@destiny.com')
                ->to($email)
                ->subject('Tower Of Destiny - Password Reset')
                ->text('Click here to reset your password: ' . $resetLink);

            $mailer->send($message);

            $this->addFlash('success', 'A reset link has been sent to your email.');

            return $this->redirectToRoute('app_login');
        }

        return $this->render('reset_password/forgot_password.html.twig', [
            'forgotPasswordForm' => $form->createView(),
        ]);
    }
    #[Route('/reset-password/{token}', name: 'app_reset_password')]
    public function resetPassword(string $token): Response
    {
        return $this->render('reset_password/reset_password.html.twig', [
            'token' => $token
        ]);
    }
    #[Route('/registre', name: 'app_register')]
    public function registre(
        Request $request,
        UserPasswordHasherInterface $passwordHasher,
        EntityManagerInterface $entityManager
    ): Response {

        $user = new User();

        $form = $this->createForm(RegistrationFormType::class, $user);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {

            $user->setPassword(
                $passwordHasher->hashPassword(
                    $user,
                    $form->get('plainPassword')->getData()
                )
            );

            $entityManager->persist($user);
            $entityManager->flush();

            return $this->redirectToRoute('app_login');
        }

        return $this->render('registre/registre.html.twig', [
            'registrationForm' => $form,
        ]);
    }
}
