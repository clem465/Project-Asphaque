<?php
// src/Form/RegistrationFormType.php

namespace App\Form;

use App\Entity\User;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\Extension\Core\Type\CheckboxType;
use Symfony\Component\Form\Extension\Core\Type\EmailType;
use Symfony\Component\Form\Extension\Core\Type\PasswordType;
use Symfony\Component\Form\Extension\Core\Type\RepeatedType;
use Symfony\Component\Form\Extension\Core\Type\TextType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolver;
use Symfony\Component\Validator\Constraints\IsTrue;
use Symfony\Component\Validator\Constraints\Length;
use Symfony\Component\Validator\Constraints\NotBlank;
use Symfony\Component\Validator\Constraints\Email;

class RegistrationFormType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder
            ->add('username', TextType::class, [
                'label'       => false,
                'constraints' => [
                    new NotBlank(message: 'Choose a hero name.'),
                    new Length(
                        min: 3,
                        max: 30,
                        minMessage: 'At least {{ limit }} characters.',
                        maxMessage: 'Max {{ limit }} characters.',
                    ),
                ],
            ])
            ->add('email', EmailType::class, [
                'label'       => false,
                'constraints' => [
                    new NotBlank(message: 'Enter your email.'),
                    new Email(message: 'Invalid email address.'),
                ],
            ])
            ->add('plainPassword', RepeatedType::class, [
                'type'            => PasswordType::class,
                'mapped'          => false,
                'first_options'   => ['label' => false],
                'second_options'  => ['label' => false],
                'invalid_message' => 'Passwords do not match.',
                'constraints'     => [
                    new NotBlank(message: 'Enter a password.'),
                    new Length(
                        min: 8,
                        minMessage: 'Password must be at least {{ limit }} characters.',
                        max: 4096,
                    ),
                ],
            ])
            ->add('agreeTerms', CheckboxType::class, [
                'mapped'      => false,
                'label'       => false,
                'constraints' => [
                    new IsTrue(message: 'You must accept the Terms of the Tower.'),
                ],
            ])
        ;
    }

    public function configureOptions(OptionsResolver $resolver): void
    {
        $resolver->setDefaults([
            'data_class' => User::class,
        ]);
    }
}