<?php

namespace App\Controller;

use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;

class RpgController extends AbstractController
{
    #[Route('/', name: 'app_rpg')]
    public function index(): Response
    {
        return $this->render('rpg/index.html.twig');
    }
}
